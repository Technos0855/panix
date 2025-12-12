#include <linux/kernel.h>
#include <linux/module.h>

MODULE_LICENSE("GPL");

static int __init log_init(void) {
  printk(KERN_INFO "Hello panix!\n");
  return 0;
}

static void __exit log_exit(void) { printk(KERN_INFO "Goodbye panix!\n"); }

module_init(log_init);
module_exit(log_exit);
