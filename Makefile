FLAGS_100M  := -DSTREAM_ARRAY_SIZE=100000000
FLAGS_500M  := -DSTREAM_ARRAY_SIZE=500000000
FLAGS_1000M := -DSTREAM_ARRAY_SIZE=1000000000
FLAGS_2000M := -DSTREAM_ARRAY_SIZE=2000000000

ifeq (gcc,$(CC))
  FLAGS_500M += -mcmodel=large
  FLAGS_1000M += -mcmodel=large
  FLAGS_2000M += -mcmodel=large
endif
streamC: stream.c
	$(CC) $< -o $@
streamC_O2: stream.c
	$(CC) -O2 $< -o $@
streamC_O3: stream.c
	$(CC) -O3 $< -o $@

streamC_O2.100M: stream.c
	$(CC) $(FLAGS_100M) -O2 $< -o $@
streamC_O3.100M: stream.c
	$(CC) $(FLAGS_100M) -O3 $< -o $@
streamC_O2.500M: stream.c
	$(CC) $(FLAGS_500M) -O2 $< -o $@
streamC_O3.500M: stream.c
	$(CC) $(FLAGS_500M) -O3 $< -o $@
streamC_O2.1000M: stream.c
	$(CC) $(FLAGS_1000M) -O2 $< -o $@
streamC_O2.2000M: stream.c
	$(CC) $(FLAGS_2000M) -O2 $< -o $@
streamC_O3.1000M: stream.c
	$(CC) $(FLAGS_1000M) -O3 $< -o $@
streamC_O3.2000M: stream.c
	$(CC) $(FLAGS_2000M) -O3 $< -o $@

streamC_O2_omp: stream.c
	$(CC) -fopenmp -O2 $< -o $@
streamC_O3_omp: stream.c
	$(CC) -fopenmp -O3 $< -o $@
streamC_O2_omp.100M: stream.c
	$(CC) $(FLAGS_100M) -fopenmp -O2 $< -o $@
streamC_O3_omp.100M: stream.c
	$(CC) $(FLAGS_100M) -fopenmp -O3 $< -o $@
streamC_O2_omp.500M: stream.c
	$(CC) $(FLAGS_500M) -fopenmp -O2 $< -o $@
streamC_O3_omp.500M: stream.c
	$(CC) $(FLAGS_500M) -fopenmp -O3 $< -o $@
streamC_O2_omp.1000M: stream.c
	$(CC) $(FLAGS_1000M) -fopenmp -O2 $< -o $@
streamC_O2_omp.2000M: stream.c
	$(CC) $(FLAGS_2000M) -fopenmp -O2 $< -o $@
streamC_O3_omp.1000M: stream.c
	$(CC) $(FLAGS_1000M) -fopenmp -O3 $< -o $@
streamC_O3_omp.2000M: stream.c
	$(CC) $(FLAGS_2000M) -fopenmp -O3 $< -o $@

mysecond.o: mysecond.c

streamF: stream.f mysecond.o
	$(FC) $^ -o $@
streamF_O2: stream.f mysecond.o
	$(FC) -O2 $^ -o $@
streamF_O3: stream.f mysecond.o
	$(FC) -O3 $^ -o $@

streamF_O2.100M: stream.f mysecond.o
	$(FC) $(FLAGS_100M) -O2 $^ -o $@
streamF_O3.100M: stream.f mysecond.o
	$(FC) $(FLAGS_100M) -O3 $^ -o $@
streamF_O2.500M: stream.f mysecond.o
	$(FC) $(FLAGS_500M) -O2 $^ -o $@
streamF_O3.500M: stream.f mysecond.o
	$(FC) $(FLAGS_500M) -O3 $^ -o $@
streamF_O2.1000M: stream.f mysecond.o
	$(FC) $(FLAGS_1000M) -O2 $^ -o $@
streamF_O3.1000M: stream.f mysecond.o
	$(FC) $(FLAGS_1000M) -O3 $^ -o $@

streamF_O2_omp: stream.f mysecond.o
	$(FC) -fopenmp -O2 $^ -o $@
streamF_O3_omp: stream.f mysecond.o
	$(FC) -fopenmp -O3 $^ -o $@
streamF_O2_omp.100M: stream.f mysecond.o
	$(FC) -fopenmp $(FLAGS_100M) -O2 $^ -o $@
streamF_O3_omp.100M: stream.f mysecond.o
	$(FC) -fopenmp $(FLAGS_100M) -O3 $^ -o $@
streamF_O2_omp.500M: stream.f mysecond.o
	$(FC) -fopenmp $(FLAGS_500M) -O2 $^ -o $@
streamF_O3_omp.500M: stream.f mysecond.o
	$(FC) -fopenmp $(FLAGS_500M) -O3 $^ -o $@
streamF_O2_omp.1000M: stream.f mysecond.o
	$(FC) -fopenmp $(FLAGS_1000M) -O2 $^ -o $@
streamF_O3_omp.1000M: stream.f mysecond.o
	$(FC) -fopenmp $(FLAGS_1000M) -O3 $^ -o $@

PROGRAMS = streamC streamC_O3 streamC_O2 streamC_O3_omp streamC_O2_omp \
	   streamF streamF_O2 streamF_O3 streamF_O3_omp streamF_O2_omp \
	   streamC_O3.100M streamC_O2.100M streamF_O2.100M streamF_O3.100M \
	   streamC_O3.500M streamC_O2.500M streamF_O2.500M streamF_O3.500M \
	   streamC_O3.1000M streamC_O2.1000M streamF_O2.1000M streamF_O3.1000M \
	   streamC_O3.2000M streamC_O2.2000M \
	   streamC_O3_omp.100M streamC_O2_omp.100M streamF_O2_omp.100M streamF_O3_omp.100M \
	   streamC_O3_omp.500M streamC_O2_omp.500M streamF_O2_omp.500M streamF_O3_omp.500M \
	   streamC_O3_omp.1000M streamC_O2_omp.1000M streamF_O2_omp.1000M streamF_O3_omp.1000M \
	   streamC_O3_omp.2000M streamC_O2_omp.2000M
EXEX := 

all: $(PROGRAMS)
clean:
	rm stream[a-Z]* *.o
check: $(PROGRAMS)
	for prog in $(PROGRAMS); do \
	  echo "#================================================================================"; \
	  echo $$prog; \
	    $(EXEC) ./$$prog  > $${prog}.log; \
	  done
