require 'pp'
require 'rake/clean'
require 'rake/loaders/makefile'
#===========================================================
# general setup for building
@defaults  = {
  CC: 'gcc',
  FC: 'gfortran',
  F77: 'gfortran'
}

@conf = {}
%w[CC CXX FC F77 CFLAGS CPPFLAGS CXX CXXFLAGS FCFLAGS LDFLAGS LIBS].each {|key| 
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
#===========================================================
# main targets

desc 'build mysecond.o'
file 'mysecond.o' => 'mysecond.c' do
  sh [@conf[:CC],'-O2 -c','mysecond.c'].join(' ')
end; CLEAN.include('mysecond.o')

OPT_FLAGS  = %w[02 03]
ArraySizes = [1,5,10,15,20].map {|i| i*=10000000}
BaseBins   = %w[stream stream_mpi]

allPrograms = []
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
          allPrograms << binaryName
        }
      }
    }
  }
}

task :all => allPrograms

task :check do
  withMpi    = allPrograms.grep(/mpi/)
  withOpenmp = allPrograms.grep(/OpenMPtrue/)
  openmpOnly = withOpenmp - withMpi
  mpiOnly    = withMpi - withOpenmp
  hybrid     = withMpi & withOpenmp
  remaining  = allPrograms - withOpenmp - withMpi

  pp hybrid
  return

  #run plain program 
  remaining.each {|prog|
    puts "# #{prog} ".ljust(80,'=')
    sh "./#{prog} 2>&1 | tee LOG.#{prog} | grep Triad > TRI.#{prog}"
  }

  # check mpi-only oprogram
  # check openmp-only programs
  # check hybrid executables
end
