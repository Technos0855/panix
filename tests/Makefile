KERNEL_VERSION=6.12.61

obj-m = log.o dev_char.o proc_char.o

all:
	echo $(OBJECTS)
	make -C ../linux-$(KERNEL_VERSION) M=$(PWD) modules

clean:
	make -C ../linux-$(KERNEL_VERSION) M=$(PWD) clean
