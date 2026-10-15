ifneq ($(KERNELRELEASE),)
obj-m := omen_s5.o
else
KDIR ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean

aml: os5f.asl
	iasl -p os5f os5f.asl
	xxd -i -n os5f_aml os5f.aml \
		| sed -e 's/^unsigned char os5f_aml\[\]/static unsigned char os5f_aml[] __aligned(8)/' -e '/_len/d' > os5f_aml.h
	rm -f os5f.aml

.PHONY: all clean aml
endif
