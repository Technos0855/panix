#include <linux/fs.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/uaccess.h>

MODULE_LICENSE("GPL");

static int device_open(struct inode *inode, struct file *filp) {
  printk(KERN_ALERT "Device opened.");
  return 0;
}

static int device_release(struct inode *inode, struct file *filp) {
  printk(KERN_ALERT "Device closed.");
  return 0;
}

static ssize_t device_read(struct file *filp, char *buffer, size_t length,
                           loff_t *offset) {
  char *msg = "Hello panix!\n";
  size_t msg_len = strlen(msg);

  if (*offset != 0)
    return 0;

  if (length < msg_len)
    return -EINVAL;

  if (copy_to_user(buffer, msg, msg_len))
    return -EFAULT;

  *offset = msg_len;
  return msg_len;
}

static ssize_t device_write(struct file *filp, const char *buf, size_t len,
                            loff_t *off) {
  printk(KERN_ALERT "Sorry, this operation isn't supported.\n");
  return -EINVAL;
}

static const struct proc_ops proc_fops = {
    .proc_read = device_read,
    .proc_write = device_write,
    .proc_open = device_open,
    .proc_release = device_release,
};

struct proc_dir_entry *proc_entry = NULL;

static int __init proc_char_init(void) {
  proc_entry = proc_create("panix-char", 0666, NULL, &proc_fops);
  printk(KERN_ALERT "/proc/panix-char created!");
  return 0;
}

static void __exit proc_char_exit(void) {
  if (proc_entry)
    proc_remove(proc_entry);
  printk(KERN_ALERT "/proc/panix-char removed!");
}

module_init(proc_char_init);
module_exit(proc_char_exit);
