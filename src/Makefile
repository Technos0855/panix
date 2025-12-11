obj-m = hello_log.o
KERNEL_VERSION=6.12.61

all:
	echo $(OBJECTS)
	make -C ../linux-$(KERNEL_VERSION) M=$(PWD) modules

clean:
	make -C ../linux-$(KERNEL_VERSION) M=$(PWD) clean
