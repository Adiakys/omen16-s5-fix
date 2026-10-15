// SPDX-License-Identifier: GPL-2.0
#define pr_fmt(fmt) "omen_s5: " fmt
#include <linux/acpi.h>
#include <linux/dmi.h>
#include <linux/module.h>
#include <linux/reboot.h>

#include "os5f_aml.h"

static const struct dmi_system_id omen_s5_dmi[] = {
	{
		.matches = {
			DMI_MATCH(DMI_SYS_VENDOR, "HP"),
			DMI_MATCH(DMI_BOARD_NAME, "8E35"),
		},
	},
	{ }
};
MODULE_DEVICE_TABLE(dmi, omen_s5_dmi);

static int omen_s5_power_off_prepare(struct sys_off_data *data)
{
	unsigned long long ret = 0;
	acpi_status status;

	status = acpi_evaluate_integer(NULL, "\\OS5F", NULL, &ret);
	if (ACPI_FAILURE(status))
		pr_err("\\OS5F failed: %s\n", acpi_format_exception(status));
	else
		pr_info("dGPU power-off before S5: %s\n", ret ? "done" : "objects not found");
	return NOTIFY_DONE;
}

static int __init omen_s5_init(void)
{
	struct sys_off_handler *handler;
	acpi_handle h;
	acpi_status status;
	u32 idx;

	if (!dmi_check_system(omen_s5_dmi))
		return -ENODEV;
	if (ACPI_FAILURE(acpi_get_handle(NULL, "\\_SB.PCI0.GPP0.PEGP._PS3", &h)) ||
	    ACPI_FAILURE(acpi_get_handle(NULL, "\\_SB.PCI0.GPP0.PEGP.OMPR", &h))) {
		pr_err("PEGP._PS3/OMPR not found in firmware tables\n");
		return -ENODEV;
	}
	if (ACPI_FAILURE(acpi_get_handle(NULL, "\\OS5F", &h))) {
		status = acpi_load_table((struct acpi_table_header *)os5f_aml, &idx);
		if (ACPI_FAILURE(status)) {
			pr_err("loading SSDT failed: %s\n", acpi_format_exception(status));
			return -EIO;
		}
	}
	handler = register_sys_off_handler(SYS_OFF_MODE_POWER_OFF_PREPARE, SYS_OFF_PRIO_HIGH,
					   omen_s5_power_off_prepare, NULL);
	if (IS_ERR(handler))
		return PTR_ERR(handler);
	pr_info("ready: dGPU will be powered off before S5\n");
	return 0;
}
module_init(omen_s5_init);

MODULE_DESCRIPTION("HP OMEN 16 (8E35): power off the dGPU before S5 so the laptop really turns off");
MODULE_LICENSE("GPL");
