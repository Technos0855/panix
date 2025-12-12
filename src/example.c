#include <linux/kernel.h>
#include <linux/module.h>

MODULE_LICENSE("GPL");

static int __init log_init(void) {
  printk(KERN_INFO "This is an example module.\n");
  return 0;
}

static void __exit log_exit(void) { printk(KERN_INFO "Exiting!\n"); }

module_init(log_init);
module_exit(log_exit);
