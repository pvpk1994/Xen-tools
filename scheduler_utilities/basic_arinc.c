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

#define DEFAULT_TIMESLICE	1

struct dom_attr {
	int wcet;
	int period;
};

int gcd(int a, int b) { return (b == 0) ? a : gcd(b, a % b); }

int lcm(int a, int b) { return (a * b)/gcd(a,b); }

void copy_uuid(xen_domain_handle_t dest, xen_domain_handle_t src)
{
	memcpy(dest, src, sizeof(xen_domain_handle_t));
}

int calculate_hyperperiod(struct dom_attr *attrs, int count)
{
	if (count == 0)
		return 0;

	int result = attrs[0].period;
	for (int i = 1; i < count; ++i)
		result = lcm(result, attrs[i].period);

	return result;
}

void compute_schedule(struct dom_attr *attrs, int hp, int count,
		      struct xen_sysctl_arinc653_schedule *sched,
		      libxl_dominfo *info)
{
	sched->major_frame = hp;

	for (int dom =0; dom < count; dom++) {
		for (int wcet = 0; wcet < attrs[dom].wcet; wcet++) {
			sched->sched_entries[sched->num_sched_entries].runtime = DEFAULT_TIMESLICE;
			copy_uuid(sched->sched_entries[sched->num_sched_entries].dom_handle,
				  info[dom].uuid.uuid);

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
		copy_uuid(sched->sched_entries[entry].dom_handle, (xen_domain_handle_t){0xff});
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
	int nb_domain, hp;

	if (libxl_ctx_alloc(&ctx, LIBXL_VERSION, 0, NULL) != 0) {
		printf("Failed to allocate libxl_ctx_allocate");
		return -1;
	}

	info = libxl_list_domain(ctx, &nb_domain);
	if (!info) {
		printf("libxl_list_domain failed.\n");
		return -1;
	}

	dom_attrs = malloc(sizeof(struct dom_attr) * nb_domain);

	for (int i=0; i < nb_domain; i++) {
		printf("Enter WCET for Domain-%d: ", info[i].domid);
		scanf("%d", &dom_attrs[i].wcet);

		printf("Enter period for Domain-%d: ", info[i].domid);
		scanf("%d", &dom_attrs[i].period);

		if (dom_attrs[i].period < dom_attrs[i].wcet) {
			printf("Period cannot be less than WCET\n");
			return -1;
		}
	}

	hp = calculate_hyperperiod(dom_attrs, nb_domain);
	printf("Hyperperiod is: %d\n", hp);

	compute_schedule(dom_attrs, hp, nb_domain, &sched, info);

	dump_schedule(sched);

    return 0;
}
