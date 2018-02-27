require 'pp'
require 'rake/clean'
require 'rake/loaders/makefile'
require 'unifiedPlot'
#===========================================================
Rake.verbose(ENV.has_key?('V'))
#===========================================================
# general setup for building
@defaults  = {
  CC: 'gcc',
  FC: 'gfortran',
  F77: 'gfortran',
  MPICC: 'mpicc',
  MPIF90: 'mpif90',
  OMP_THREADS: 4,
    MPI_TASKS: 4,
    MPIRUN: 'mpirun'
}

@conf = {}
%w[CC CXX FC F77 MPICC MPIF90 CFLAGS CPPFLAGS CXX CXXFLAGS FCFLAGS LDFLAGS LIBS OMP_THREADS MPI_TASKS MPIRUN].each {|key|
  keySym = key.to_sym
  @conf[keySym] = ENV.has_key?(key) ? ENV[key] : (@defaults.has_key?(keySym) ? @defaults[keySym] : '')
}
%w[OMP_THREADS MPI_TASKS].each {|k| @conf[k.to_sym] = @conf[k.to_sym].to_i}

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
@binDb       = {}
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
            comp = ('C' == lang) ? @conf[:MPICC] : @conf[:MPIF90]
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
          @binDb[binaryName] = {lang: lang, useMPI: useMPI, optflag: optflag, arySize: arySize}
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
# pp @memRates
# pp @binDb.values_at(*@memRates.keys)
  @data = {}
  # compare arySize in differen optflags
  %w[C F].each {|lang|
    @data[lang] = {}
    OPT_FLAGS.each {|optflag|
      @data[lang][optflag] = []
      @memRates.each {|exe,rate|
        if (@binDb[exe][:lang] == lang and @binDb[exe][:optflag] == optflag) then
          @data[lang][optflag] << [@binDb[exe][:arySize],rate[0]]
        end
      }
    }
  }

  pp @data['C']['02']
  pp @data['F']['02']
  # compare fortran with different opt levels
  data2plot = []
  f02 = @data['F']['02'].transpose
  f03 = @data['F']['03'].transpose
  data2plot << {x: f02[0],y: f02[1],title: 'Fortran version, opt: -O2'}
  data2plot << {x: f03[0],y: f03[1],title: 'Fortran version, opt: -O3'}
  # compare c versions
  c02 = @data['C']['02'].transpose
  c03 = @data['C']['03'].transpose
  data2plot << {x: c02[0],y: c02[1],title: 'C version, opt: -O2'}
  data2plot << {x: c03[0],y: c03[1],title: 'C version, opt: -O3'}

  UnifiedPlot.linePlot(data2plot,oName: "#{t.name}_FvsC_noOpenMP_noMPI",
                       oType: 'png',
                       :plotConf => {:title => "Stream Benchmark, Fortran and C versions, host:#{`hostname`.chomp}",
                                     xlabel: "Array Size",ylabel: "Memory Bandwidth [MB/s]",
                                     yrange: "[8000:12000]"}
                      )
end
def collectData(memRates,binDb)
  data={}
  %w[C F].each {|lang|
    data[lang] = {}
    OPT_FLAGS.each {|optflag|
      data[lang][optflag] = []
      memRates.each {|exe,rate|
        if (binDb[exe][:lang] == lang and binDb[exe][:optflag] == optflag) then
          data[lang][optflag] << [binDb[exe][:arySize],rate.transpose]
        end
      }
    }
  }
  data
end
def nonHybridPlots(data,name,type)
  f02 = data['F']['02'].transpose
  f03 = data['F']['03'].transpose
  # compare c versions
  c02 = data['C']['02'].transpose
  c03 = data['C']['03'].transpose
  pp c03
  pp c03[1][0]
  data2plot = []
  title = ('omp' == type) ? 'OpenMP' : 'MPI'
  f02[0].each_with_index {|arySize,i|
    data2plot << {x: f02[1][i][0],y: f02[1][i][1],title: "arraySize #{arySize}",style: 'linespoints lw 2'}
  }
  UnifiedPlot.linePlot(data2plot,oName: "#{name}_F_02_#{type}",oType: 'png',
                        plotConf: {title: "#{title}-Test: Fortran version, opt: -O2",key: 'bot'})
  data2plot= []
  f03[0].each_with_index {|arySize,i|
    data2plot << {x: f03[1][i][0],y: f03[1][i][1],title: "arraySize #{arySize}",style: 'linespoints lw 2'}
  }
  UnifiedPlot.linePlot(data2plot,oName: "#{name}_F_03_#{type}",oType: 'png',
                        plotConf: {title: "#{title}-Test: Fortran version, opt: -O3",key: 'bot'})
  data2plot.clear
  c02[0].each_with_index {|arySize,i|
    data2plot << {x: c02[1][i][0],y: c02[1][i][1],title: "arraySize #{arySize}",style: 'linespoints lw 2'}
  }
  UnifiedPlot.linePlot(data2plot,oName: "#{name}_C_02_#{type}",oType: 'png',
                        plotConf: {title: "#{title}-Test: C version, opt: -O2",key: 'bot'})
  data2plot.clear
  c03[0].each_with_index {|arySize,i|
    data2plot << {x: c03[1][i][0],y: c03[1][i][1],title: "arraySize #{arySize}",style: 'linespoints lw 2'}
  }
  pp data2plot
  UnifiedPlot.linePlot(data2plot,oName: "#{name}_C_03_#{type}",oType: 'png',
                        plotConf: {title: "#{title}-Test: C version, opt: -O3",key: 'bot'})
  data2plot.clear
end
task :checkOmp    => @checkTasks[:omp] do |t|
  data = collectData(@memRates,@binDb)
  nonHybridPlots(data,t.name,'omp')
end
task :checkMpi    => @checkTasks[:mpi] do |t|
  data = collectData(@memRates,@binDb)
  nonHybridPlots(data,t.name,'mpi')
end
def hybridPlot(data,opt,lang,name)
  sizes = data[0]
  sizes.each_with_index {|size,i|
    pp size
    mpi  = data[1][i][0]
    omp  = data[1][i][1]
    rate = data[1][i][2]
    _d = {}
    _d[:x] = mpi
    _d[:y] = omp
    _d[:z] = rate
    pp rate
    UnifiedPlot.heatMap(_d,oName: "#{name}_#{lang}_#{opt}_hybrid_arraySize#{size}",oType: 'png',
                        plotConf: {title: "Hybrid-Test: #{lang} version -#{opt}, ArraySize:#{size}",\
                                   xlabel: "MPI tasks",ylabel: "OpenMP threads",
                                   xtics: '1',ytics: '1',xsize: 1600,cbrange: "[0:800000]",
                                   xrange: "[0.5:#{mpi.max+0.5}]", yrange: "[0.5:#{omp.max+0.5}]"})
  }
end
task :checkHybrid => @checkTasks[:hybrid] do |t|
  pp @memRates
  data = collectData(@memRates, @binDb)

  f02 = data['F']['02'].transpose
  f03 = data['F']['03'].transpose
  c02 = data['C']['02'].transpose
  c03 = data['C']['03'].transpose

  hybridPlot(c02,'02','C',t.name)
  hybridPlot(c03,'03','C',t.name)
  hybridPlot(f02,'02','F',t.name)
  hybridPlot(f03,'03','F',t.name)
end
task :check       => [:checkOmp,:checkMpi,:checkHybrid,:checkPlain]
desc "Create a source tar-ball"
task :archive do
  sh "git archive --prefix=stream/ -o stream.tar.gz master"
end
