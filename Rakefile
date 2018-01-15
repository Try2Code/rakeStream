require 'pp'
require 'rake/clean'
require 'rake/loaders/makefile'
#===========================================================
Rake.verbose(ENV.has_key?('V'))
#===========================================================
# general setup for building
@defaults  = {
  CC: 'gcc',
  FC: 'gfortran',
  F77: 'gfortran',
  OMP_THREADS: 4,
    MPI_TASKS: 4,
    MPIRUN: 'mpirun'
}

@conf = {}
%w[CC CXX FC F77 CFLAGS CPPFLAGS CXX CXXFLAGS FCFLAGS LDFLAGS LIBS OMP_THREADS MPI_TASKS MPIRUN].each {|key| 
  keySym = key.to_sym
  @conf[keySym] = ENV.has_key?(key) ? ENV[key] : (@defaults.has_key?(keySym) ? @defaults[keySym] : '')
}

case @conf[:CC]
when 'gcc'
  @conf[:OMP_FLAG] = ' -fopenmp'
  @conf[:FCFLAGS] << ' -mcmodel=large'
  @conf[:CFLAGS] << ' -mcmodel=large -ffreestanding'
when 'ncc'
  @conf[:OMP_FLAG] = ' -fopenmp'
when 'icc'
  @conf[:OMP_FLAG] = ' -qopenmp'
  @conf[:FCFLAGS] << ' -mcmodel=large'
  @conf[:CFLAGS] << ' -mcmodel=large -ffreestanding -restrict'
else
  @conf[:OMP_FLAG] = ''
end
#-----------------------------------------------------------
def ext(fn, newext)
  fn.sub(/\.[^.]+$/, newext)
end
def dbg(*args); args.each {|arg| pp arg}; end
@filePattern = '*.{F,F90,f,h,c,inc,f90}'

file '.logs' do |t|
  sh "mkdir #{t.name}"
end
#===========================================================
# main targets

desc 'build mysecond.o'
file 'mysecond.o' => 'mysecond.c' do
  sh [@conf[:CC],'-O2 -c','mysecond.c'].join(' ')
end; CLEAN.include('mysecond.o')

OPT_FLAGS  = %w[02 03]
ArraySizes = [1,5,10,15,20].map {|i| i*=10000000}
BaseBins   = %w[stream stream_mpi]

@allPrograms = []
BaseBins.each {|binary|
  useMPI = /mpi$/.match(binary)
  binaryName = binary
  %w[C F].each {|lang|
    srcFile = binary+'.'+lang.downcase
    [true,false].each {|useOpenMP|
      OPT_FLAGS.each {|optflag|
        ArraySizes.each {|arySize|
          binaryName = [binary,lang,"OpenMP#{useOpenMP.to_s}",optflag,arySize].join('_')

          if useMPI then
            comp = ('C' == lang) ? 'mpicc' : 'mpif90'
          else
            comp = ('C' == lang) ? @conf[:CC] : @conf[:FC]
          end

          flags = []
          flags << (('C' == lang) ? @conf[:CFLAGS] : @conf[:FCFLAGS])
          flags << " -DSTREAM_ARRAY_SIZE=#{arySize}"
          flags << @conf[:OMP_FLAG] if useOpenMP

          desc "build binary: #{binaryName}"
          file binaryName  =>  [srcFile,'mysecond.o'] do |t|
            if 'C' == lang then
              sh [comp ,@conf[:CPPFLAGS],flags.join(' ') ,srcFile,'-o',t.name].join(' ')
            else
              sh [comp ,@conf[:CPPFLAGS],flags.join(' ') ,srcFile,' mysecond.o -o',t.name].join(' ')
            end
          end
          CLEAN.include(binaryName)
          @allPrograms << binaryName
        }
      }
    }
  }
}
@withMpi    = @allPrograms.grep(/mpi/)
@withOpenmp = @allPrograms.grep(/OpenMPtrue/)
@openmpOnly = @withOpenmp - @withMpi
@mpiOnly    = @withMpi - @withOpenmp
@hybrid     = @withMpi & @withOpenmp
@remaining  = @allPrograms - @withOpenmp - @withMpi

desc "Build all executables"
task :all => @allPrograms

# collect the memory rates
@memRates = {}
class Array
  def grep4Triad
    needle = self.grep(/^Triad/)
    return 0.0 if needle.empty?
    return needle.first.split[1].to_f
  end
end
def plainCheck(exe)
  cmd     = "./#{exe}"
  puts cmd if Rake.verbose
  memRate = IO.popen(cmd + " | tee .logs/#{exe}.log").readlines.grep4Triad
  return memRate
end
def ompCheck(omp, exe)
  cmd     = "OMP_NUM_THREADS=#{omp} ./#{exe}"
  puts cmd if Rake.verbose
  memRate = IO.popen(cmd + " | tee .logs/#{exe}_omp.eq.#{omp}.log").readlines.grep4Triad
  return memRate
end
def mpiCheck(mpi,mpirun,exe)
  cmd     = "#{mpirun} -np #{mpi} ./#{exe}"
  puts cmd if Rake.verbose
  memRate = IO.popen(cmd + " | tee .logs/#{exe}_mpi.eq.#{mpi}.log").readlines.grep4Triad
  return memRate
end
def hybridCheck(mpi,omp, mpirun, exe)
  cmd     = "OMP_NUM_THREADS=#{omp} #{mpirun} -np #{mpi} ./#{exe}"
  puts cmd if Rake.verbose
  memRate = IO.popen(cmd + " | tee .logs/#{exe}_mpi.eq.#{mpi}_omp.eq.#{omp}.log").readlines.grep4Triad
  return memRate
end
def scalingList(max)

  return [1] if 1 == max

  maxLog2 = Math.log2(max)

  list = []
  list << max  if maxLog2.to_i != maxLog2
  halfWay = 0.584962500721156

  Math.log2(max).floor.downto(1) {|n|
    list << 2**n
    list << (2**(n-1+halfWay)).to_i
  }
  list
end
# create targest for checking all binaries
@memRates   = {}
@checkTasks = {plain: [],omp: [], mpi: [], hybrid: []}
# plain
@remaining.each {|exe|
  taskName = "run_#{exe}"
  CLEAN.include(taskName)

  desc "Run #{exe}"
  file taskName => exe  do |t|
    rate = plainCheck(exe)
    sh "echo #{rate} > #{taskName}"
  end
  task "check_#{exe}" => taskName do
    rate = File.open(taskName).read.chomp.to_f
    (@memRates[exe] ||= []) << rate
  end
  @checkTasks[:plain] << "check_#{exe}"
}
# openmp
taskNameGen = lambda {|exe,omp,prefix| "#{prefix}_#{exe}_omp.eq.#{omp}"}
@openmpOnly.each {|exe|
  scalingList(@conf[:OMP_THREADS].to_f).each {|omp|
    taskName = taskNameGen.call(exe,omp,'run')
    CLEAN.include(taskName)

    desc "Run #{exe} with nthreads = #{omp}"
    file taskName => exe do |t|
      rate = ompCheck(omp,exe)
      sh "echo #{rate} > #{taskName}"
    end

    @checkTasks[:omp] << taskNameGen.call(exe,omp,'check')
    desc "Check results from #{exe}"
    task taskNameGen.call(exe,omp,'check') => taskName do
      rate = File.open(taskName).read.chomp.to_f
      puts [rate,taskName].join("\t") if Rake.verbose
      (@memRates[exe] ||= []) << [omp,rate]
    end
  }
}
# mpi
taskNameGen = lambda {|exe,mpi,prefix| "#{prefix}_#{exe}_mpi.eq.#{mpi}"}
@mpiOnly.each {|exe|
  scalingList(@conf[:MPI_TASKS].to_f).each {|mpi|
    taskName = taskNameGen.call(exe,mpi,'run')
    CLEAN.include(taskName)

    desc "Run #{exe} with mpi-tasks = #{mpi}"
    file taskName => exe do |t|
      sh "echo #{mpiCheck(mpi,@conf[:MPIRUN],exe)} > #{taskName}"
    end

    @checkTasks[:mpi] << taskNameGen.call(exe,mpi,'check')
    desc "Check results from #{exe} with mpi-taskName = #{mpi}"
    task taskNameGen.call(exe,mpi,'check') => taskName do
      rate = File.open(taskName).read.chomp.to_f
      puts [exe,mpi,rate].reverse.join("\t") if Rake.verbose
      (@memRates[exe] ||= []) << [mpi,rate]
    end
  }
}
# hybrid
taskNameGen = lambda {|exe,mpi,omp,prefix| "#{prefix}_#{exe}_mpi.eq.#{mpi}_omp.eq.#{omp}"}
@hybrid.each {|exe|
  scalingList(@conf[:MPI_TASKS].to_f).each {|mpi|
    scalingList(@conf[:OMP_THREADS].to_f).each {|omp|
      taskName = taskNameGen.call(exe,mpi,omp, "run")
      CLEAN.include(taskName)

      desc "Run #{exe} with mpi-tasks = #{mpi}/nthreads = #{omp}"
      file taskName => exe do |t|
         sh "echo #{hybridCheck(mpi,omp,@conf[:MPIRUN],exe)} > #{taskName}"
      end

      @checkTasks[:hybrid] << taskNameGen.call(exe,mpi,omp,'check')
      desc "Check results from hybrid run with #{exe}: mpi = #{mpi}, omp = #{omp}"
      task taskNameGen.call(exe,mpi,omp,'check') => taskName do
        rate = File.open(taskName).read.chomp.to_f
        puts [exe,mpi,omp,rate].reverse.join("\t") if Rake.verbose
        (@memRates[exe] ||= []) << [mpi,omp,rate]
      end
    }
  }
}
task :checkTasklist do
  %w[96 108 12 48 34 18 16 8 4 2 1].each {|n| pp scalingList(n.to_i) }
end
task :checkConf do
  pp @conf
end
task :checkPlain  => @checkTasks[:plain] do |t|
  pp @memRates
end
task :checkOmp    => @checkTasks[:omp]
task :checkMpi    => @checkTasks[:mpi]
task :checkHybrid => @checkTasks[:hybrid]
task :check       => [:checkOmp,:checkMpi,:checkHybrid,:checkPlain]
desc "Create a source tar-ball"
task :archive do
  sh "git archive --prefix=stream/ -o stream.tar.gz master"
end
