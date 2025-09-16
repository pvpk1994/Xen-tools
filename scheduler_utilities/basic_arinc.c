/*
 * A basic ARINC-653 scheduler utility code that generates
 * a simple non-preemptive schedule
 * Author: Pavan Kumar Paluri
 * Procedure to run: gcc basic_arinc.c -o basic_arinc -lxenctrl -luuid -lxenlight
 * pkg-config --cflags xencontrol // returns -I/usr/include/xen
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <xenctrl.h>    /* For obtaining ARINC 653 scheduler info */
#include <libxl.h>      /* For obtaining DomU information */
#include <uuid/uuid.h> /* For parsing DomU's handle */
#include <libxl_utils.h> /* For libxl bitmap operations */

#define MILLISECS(x)		((x) * 1000000ULL)
#define DEFAULT_TIMESLICE	MILLISECS(10)

struct dom_attr {
	libxl_uuid uuid;
	libxl_domid domid;
	int wcet;
	int period;
};

int gcd(int a, int b) { return (b == 0) ? a : gcd(b, a % b); }

int lcm(int a, int b) { return (a * b)/gcd(a,b); }

int calculate_hyperperiod(struct dom_attr *attrs, int count)
{
	if (count == 0)
		return 0;

	int result = attrs[0].period;
	for (int i = 1; i < count; ++i)
		result = lcm(result, attrs[i].period);

	return result;
}

void compute_schedule(libxl_ctx *ctx, struct dom_attr *attrs, int hp, int count,
		      struct xen_sysctl_arinc653_schedule *sched)
{
	libxl_uuid idle_dom;
	memset(&idle_dom, 0, sizeof(idle_dom));

	sched->major_frame = hp;
	printf("Hyperperiod obtained is: %ld\n", sched->major_frame);

	for (int dom =0; dom < count; dom++) {
		for (int wcet = 0; wcet < attrs[dom].wcet; wcet++) {
			sched->sched_entries[sched->num_sched_entries].runtime = DEFAULT_TIMESLICE;

			memcpy(&sched->sched_entries[sched->num_sched_entries].dom_handle,
			       &attrs[dom].uuid, sizeof(libxl_uuid));

			/* TODO: when multi-vCPU support is introduced, this needs change */
			sched->sched_entries[sched->num_sched_entries].vcpu_id = 0;
			sched->num_sched_entries++;
		}
	}

	if (sched->major_frame < sched->num_sched_entries) {
		printf("Number of schedule entries exceeded major frame. Aborting...\n");
		return;
	}

	else if (sched->major_frame == sched->num_sched_entries) {
		printf("There are no idle time slices\n");
		return;
	}

	/* Consume up the remaining time-slices with idle entries */
	for (int entry = sched->num_sched_entries; entry < sched->major_frame; entry++) {
		sched->sched_entries[entry].runtime = DEFAULT_TIMESLICE;

		/* For idle schedule-entry's domain handle, use Domain-0's handle as a
		 * placeholder. This is a safe operation because the arinc cpupool will
		 * never have a Domain-0 included in it's schedule.
		 */
		memcpy(&sched->sched_entries[entry].dom_handle, &idle_dom, sizeof(libxl_uuid));
	}

	return;
}

void print(xen_domain_handle_t handle)
{
	for (int i=0; i <16; ++i)
		printf("%02x", handle[i]);

	printf("\n");
}

void dump_schedule(struct xen_sysctl_arinc653_schedule sched)
{
	for (int ts = 0; ts < sched.major_frame; ts++)
		print(sched.sched_entries[ts].dom_handle);
}

int main()
{
	struct xen_sysctl_arinc653_schedule sched = {0};
	struct dom_attr *dom_attrs;
	libxl_ctx *ctx;
	libxl_dominfo *info;
	libxl_cpupoolinfo *pools, arinc_pool;
	int nb_domain, hp, npools, total_doms, arinc_dom_index=0;

	if (libxl_ctx_alloc(&ctx, LIBXL_VERSION, 0, NULL) != 0) {
		printf("Failed to allocate libxl_ctx_allocate");
		return -1;
	}

	/* Get cpupool information */
	pools = libxl_list_cpupool(ctx, &npools);

	#ifdef ENABLE_DUMP
	printf("Number of cpupools: %d\n", npools);
	#endif

	libxl_cpupoolinfo_init(&arinc_pool);

	for (int i=0; i < npools; i++) {
		if (strcmp(pools[i].pool_name, "arinc_pool") == 0) {
			arinc_pool.pool_name = strdup(pools[i].pool_name);

			#ifdef ENABLE_DUMP
			printf("POOL NAME: %s\n", arinc_pool.pool_name);
			#endif

			if (pools[i].cpumap.size == 0) {
				fprintf(stderr, "Invalid cpumap size: 0\n");
				return -1;
			}

			libxl_bitmap_copy_alloc(ctx, &arinc_pool.cpumap, &pools[i].cpumap);

			#ifdef ENABLE_DUMP
			printf("arinc_pool.cpumap.size: 0x%x\n", arinc_pool.cpumap.size);
			printf("pool[i].cpumap.size: 0x%x\n", pools[i].cpumap.size);
			#endif

			arinc_pool.poolid = pools[i].poolid;
			arinc_pool.sched = pools[i].sched;
			arinc_pool.n_dom = pools[i].n_dom;
			break;
		}
	}


	dom_attrs = malloc(arinc_pool.n_dom * sizeof(*dom_attrs));
	if (!dom_attrs) {
		fprintf(stderr, "malloc failure\n");
		return -1;
	}

	/* Get domain information */
	info = libxl_list_domain(ctx, &total_doms);

	for (int i=0; i < total_doms; i++) {
		if (info[i].cpupool == arinc_pool.poolid) {

			if (arinc_dom_index >= arinc_pool.n_dom) {
				fprintf(stderr, "More domains expected in cpupool\n");
				break;
			}

			dom_attrs[arinc_dom_index].domid = (uint32_t)info[i].domid;
			libxl_uuid_copy(ctx, &dom_attrs[arinc_dom_index].uuid, &info[i].uuid);
			arinc_dom_index++;
		}
	}

	for (int i=0; i < arinc_pool.n_dom; i++) {
		printf("Enter WCET for Domain-%d: ", dom_attrs[i].domid);
		scanf("%d", &dom_attrs[i].wcet);

		printf("Enter period for Domain-%d: ", dom_attrs[i].domid);
		scanf("%d", &dom_attrs[i].period);

		if (dom_attrs[i].period < dom_attrs[i].wcet) {
			printf("Period cannot be less than WCET\n");
			return -1;
		}
	}

	hp = calculate_hyperperiod(dom_attrs, arinc_pool.n_dom);
	printf("Hyperperiod is: %d\n", hp);

	compute_schedule(ctx, dom_attrs, hp, arinc_pool.n_dom, &sched);

#ifdef ENABLE_DUMP
	dump_schedule(sched);
#endif

    return 0;
}
