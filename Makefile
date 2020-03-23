#platform-specific configuration
include Configuration.mk

# Be silent per default, but 'make V=1' will show all compiler calls.
ifneq ($(V),1)
export Q := @
# Do not print "Entering directory ...".
MAKEFLAGS += --no-print-directory
endif

#arch confs.
ARCH = riscv/hf-riscv
IMAGE_NAME = image

#dir config.
HFOS_DIR = hellfireos

CPU_ARCH = \"$(ARCH)\"
MAX_TASKS = 30
MUTEX_TYPE = 0
MEM_ALLOC = 3
HEAP_SIZE = 500000
FLOATING_POINT = 0
#KERNEL_LOG = 2
KERNEL_LOG = $(KERNEL_LOG_LEVEL)

SRC_DIR = $(HFOS_DIR)

# do not move this from here 
all:  $(IMAGE_NAME).bin
	@echo "done"

#includes for kernel parts
include $(HFOS_DIR)/arch/$(ARCH)/arch.mak
include $(HFOS_DIR)/lib/lib.mak
include $(HFOS_DIR)/drivers/noc.mak
include $(HFOS_DIR)/sys/kernel.mak

#compile only the requested tasks 
$(foreach module,$(ORCA_APPLICATIONS),$(eval include applications/$(module)/app.mak))
#compile only the requested extensions 
$(foreach module,$(ORCA_EXTENSIONS),$(eval include extensions/$(module)/ext.mak))

#phonies
.PHONY: clean

# common definition to all software modules
INC_DIRS += -I $(HFOS_DIR)/lib/include \
			-I $(HFOS_DIR)/sys/include \
			-I $(HFOS_DIR)/drivers/noc/include \
			-I $(HFOS_DIR)/../extensions/orca-core/include \
			-I $(HFOS_DIR)/../extensions/orca-monitoring/include \
			-I $(HFOS_DIR)/../extensions/orca-pubsub/include

NOC_FLAGS = -DNOC_INTERCONNECT -DNOC_PACKET_SIZE=64 -DNOC_PACKET_SLOTS=64 \
	    -DNOC_WIDTH=$(ORCA_NOC_WIDTH) -DNOC_HEIGHT=$(ORCA_NOC_HEIGHT)

CFLAGS += -DCPU_ARCH=$(CPU_ARCH) \
	-DMAX_TASKS=$(MAX_TASKS) -DMEM_ALLOC=$(MEM_ALLOC) \
	-DHEAP_SIZE=$(HEAP_SIZE) -DMUTEX_TYPE=$(MUTEX_TYPE) \
	-DFLOATING_POINT=$(FLOATING_POINT) \
	-DKERNEL_LOG=$(KERNEL_LOG) \
	$(COMPLINE) \
	$(NOC_FLAGS)

# concat the required libs to build the image 
$(foreach module,$(ORCA_APPLICATIONS), $(eval APP_STATIC_LIBS := $(APP_STATIC_LIBS) app-$(module).a))
$(foreach module,$(ORCA_EXTENSIONS),   $(eval EXT_STATIC_LIBS := $(EXT_STATIC_LIBS) ext-$(module).a))
OS_STATIC_LIBS := hellfire-os.a
STATIC_LIBS := $(OS_STATIC_LIBS) $(APP_STATIC_LIBS) $(EXT_STATIC_LIBS)

$(OS_STATIC_LIBS):
	@echo "$'\e[7m==================================\e[0m"
	@echo "$'\e[7m  Making Kernel ...               \e[0m"
	@echo "$'\e[7m==================================\e[0m"
	$(Q)make hal
	$(Q)make libc
	$(Q)make noc
	$(Q)make kernel 
	$(Q)$(AR) rcs hellfire-os.a *.o

ext: ext_banner $(EXT_STATIC_LIBS)

ext_banner:
	@echo "$'\e[7m==================================\e[0m"
	@echo "$'\e[7m  Making Extensions ...           \e[0m"
	@echo "$'\e[7m==================================\e[0m"
	
app: app_banner $(APP_STATIC_LIBS)

app_banner:
	@echo "$'\e[7m==================================\e[0m"
	@echo "$'\e[7m  Making Applications ..          \e[0m"
	@echo "$'\e[7m==================================\e[0m"

$(IMAGE_NAME).bin: $(OS_STATIC_LIBS) ext app
	@echo "$'\e[7m==================================\e[0m"
	@echo "$'\e[7m  Linking Software ...            \e[0m"
	@echo "$'\e[7m==================================\e[0m"
	$(Q)$(LD) --start-group *.a --end-group $(LDFLAGS) -T$(LINKER_SCRIPT) -o $(IMAGE_NAME).elf 
	$(Q)$(DUMP) --disassemble --reloc $(IMAGE_NAME).elf > $(IMAGE_NAME).lst
	$(Q)$(DUMP) -h $(IMAGE_NAME).elf > $(IMAGE_NAME).sec
	$(Q)$(DUMP) -s $(IMAGE_NAME).elf > $(IMAGE_NAME).cnt
	$(Q)$(OBJ) -O binary $(IMAGE_NAME).elf $(IMAGE_NAME).bin
	$(Q)$(SIZE) $(IMAGE_NAME).elf
	$(Q)hexdump -v -e '4/1 "%02x" "\n"' $(IMAGE_NAME).bin > $(IMAGE_NAME).txt

clean:
	@echo "$'\e[7m==================================\e[0m"
	@echo "$'\e[7m          Cleaning up...          \e[0m"
	@echo "$'\e[7m==================================\e[0m"
	$(Q)rm -rf *.o *~ *.elf *.bin *.cnt *.lst *.sec *.txt *.a
	$(Q)-find . -type f -name '*.su' -delete
	$(Q)-find . -type f -name '*.o' -delete
	$(Q)-find . -type f -name '*.a' -delete
	$(Q)-find . -type f -name '$(IMAGE_NAME).*' -delete
	



