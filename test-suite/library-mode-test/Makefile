include ../../make.inc

include ../../src/Makefile.header

ifdef COMMS
COMMS := $(strip $(COMMS))
else
COMMS = serial
endif
# Only works in serial for now
# Otherwise, in the future, put back the logic here from 
# Makefile.2
#COMMS = serial

ifeq ($(COMMS),mpi08)
TEMP1 = -DMPI -DMPI08
TEMP2 = $(MPIF90)
else ifeq ($(COMMS),mpih)
TEMP1 = -DMPI -DMPIH
TEMP2 = $(MPIF90)
else ifeq ($(COMMS),mpi90)
TEMP1 = -DMPI -DMPI90
TEMP2 = $(MPIF90)
else ifeq ($(COMMS),mpi)
# default to f90 style "use mpi"
TEMP1 = -DMPI -DMPI90
TEMP2 = $(MPIF90)
else
TEMP1 =
TEMP2 = $(F90)
endif

librarytest: POSTOPTS = $(TEMP1) 
librarytest: COMPILER = $(TEMP2)
librarytest: test_library_serial.x

test_library_serial.x: test_library.F90 $(LIBRARY)
	$(COMPILER) $< $(POSTOPTS) $(LDOPTS) $(LIBRARY) $(LIBS) -o $@

clean:
	rm -f test_library_serial.x *~

.PHONY: clean librarytest
