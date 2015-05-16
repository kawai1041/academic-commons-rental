#!/usr/local/bin/ruby -KS
# encoding: CP932
#
# 2013.07.02:KAWAI Toshikazu
#

require 'date'

CURRENT_FILE = 'current_'
LOG_FILE = 'kashidashi_'

class Buppin
  @@today = Date.today.strftime('%Y/%m/%d')
  attr_reader :mono, :time, :time_return, :st_no, :tel_no
  def initialize(yymmdd, mono, st_no, name, tel_no, time, time_return)
    yymmdd ||= @@today
    time ||= Time.now.strftime("%H:%M")
    @yymmdd, @mono, @st_no, @name, @tel_no, @time, @time_return = yymmdd, mono, st_no, name, tel_no, time, time_return
  end

  def to_csv
    [@yymmdd, @mono, @st_no, @name, @tel_no, @time, @time_return].join(',')
  end
  def to_csv_noname
    [@yymmdd, @mono, @st_no, @tel_no, @time, @time_return].join(',')
  end
end

class Kashidashi

  def initialize
    @current_file = CURRENT_FILE + Date.today.strftime('%Y%m%d') + ".csv"
    @sumi_file    = LOG_FILE     + Date.today.strftime('%Y%m%d') + ".csv"
    @kashidashi_chu = {}
    if File.exist? @current_file
      File.open(@current_file, 'r') {|f|
        f.each {|line|
          next if line =~ /^#/
          yymmdd, mono, st_no, name, tel_no, time, time_return = line.strip.split(/,/)
          @kashidashi_chu[mono] = Buppin.new(yymmdd, mono, st_no, name, tel_no, time, time_return)
        }
      }
    end
    unless File.exist? @sumi_file
      File.open(@sumi_file, 'w') {|f|
        f.print "#このファイルを開いたまま返却操作をしたらエラーになる。\n"
        f.print "#エラーになったときは貸出ソフトを再起動し、返却操作をおこなうこと\n#\n"
        f.print "#年月日,貸出物品,学生番号,連絡先,貸出時刻,返却予定時刻,返却時刻\n"
      }
    end

  end

  def rental?(mono)
    @kashidashi_chu[mono]
  end

  def kashi(buppin)
    if @kashidashi_chu[buppin.mono]
      raise
    else
      @kashidashi_chu[buppin.mono] = buppin
      write_current
    end
  end

  def hen(mono)
    if rental?(mono)
      File.open(@sumi_file, 'a') {|f|
        f.print @kashidashi_chu[mono].to_csv_noname + "," + Time.now.strftime("%H:%M") + "\n"
      }
      @kashidashi_chu.delete(mono)
      write_current
    end
  end

  def write_current
#    p @kashidashi_chu.values
    current = @kashidashi_chu.values.sort_by {|elm| elm.time}
    File.open(@current_file, "w") {|f|
        f.print "#このファイルを開いたまま貸出返却操作をしたらエラーになる。\n"
        f.print "#エラーになったときは貸出ソフトを再起動し、貸出返却操作をおこなうこと\n#\n"
      f.print "#年月日,物品,学生番号,氏名,連絡先,貸出時刻,返却予定時刻\n"
      current.each {|elm|
        f.print elm.to_csv + "\n"
      }
    }
  end

  def get_yotei
    hen_yotei = {}
    @kashidashi_chu.keys.sort.each {|mono|
      shubetsu, no = $1, $2 if mono =~ /([\d|\w]*\w)(\d\d)/
#      p shubetsu
      hen_yotei[shubetsu] ||= []
      hen_yotei[shubetsu] << @kashidashi_chu[mono].time_return + '(' + no + ')'
    }
    result = []
#    p hen_yotei
    hen_yotei.keys.sort.each {|shu|
      result << "#{shu}\t" + hen_yotei[shu].sort.join(' ')
    }
    return result.join("\n")
  end
end



