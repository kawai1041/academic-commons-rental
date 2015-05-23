#!/usr/local/bin/ruby -KS
# encoding: CP932
## CAUTION!! ## This code was automagically ;-) created by FormDesigner.
# NEVER modify manualy -- otherwise, you'll have a terrible experience.
# 2014.10.17 フィールドの文字消去時間設定をすべての入力後に適用（物品のときは設定してなかった）


require 'drb/drb'

require 'vr/vruby'
require 'vr/vrcontrol'
require 'vr/vrhandler'

require './buppin.rb'

CLEAR_AFTER_KASHIDASHI = 2
CLEAR_AFTER_INPUT      = 3

SC_INI = './sc.ini'

class String
  def strip_quote
    ret = self
    if self =~ /^"(.*)"$/ then
      ret = $1.gsub('""', '"')
    end
    return ret
  end
end

class INIT

  attr_reader :goods, :meibo, :sc, :server_ip, :server_port

  def initialize
    @goods = {}
    File.open('./goods.csv', 'r') {|f|
     f.each {|line|
       next if /\A#/ =~ line
       bunrui, kigo = line.split(',').map {|item| item.strip}
       goods[kigo] = true
     }
    }
    @meibo = Hash.new {|h, k| h[k] = "？？？？？？"}
    File.open('./gakusei_meibo.csv', 'r') {|f|
      f.each {|line|
        next if /\A#/ =~ line
        no, name = line.strip.split(',').map {|item| item.strip_quote}
        @meibo[no] = name
      }
    }
    @sc = :server
    @server_ip = 'localhost'
    @server_port = '12345'

    if File.exist? SC_INI
      File.open(SC_INI, 'r') {|f|
        f.each {|line|
          next if /\A#/ =~ line
          @sc = :server if line =~ /\Asc:server/i
          @sc = :client if line =~ /\Asc:client/i
          @server_ip = $1 if line =~ /\Aserver_ip:(\d+\.\d+\.\d+\.\d+)/i
          @server_port = $1 if line =~ /\Aserver_port:(\d+)/i
        }
      }
    end
  end
end

class VRHookedEdit < VREdit
  include VRKeyFeasible
  def vrinit
    super
    add_parentcall("char")
  end
end

def mod10weit21?(st)
  st_a = st.split(//).reverse
  cd = st_a.shift.to_i
  weight = 2
  sum = 0
  st_a.each {|d|
    m = d.to_i * weight
    sum += ((m / 10) + (m % 10))
    weight = 3 - weight
  }
  amari = sum % 10
  if amari == 0
    amari == cd
  else
    (10 - amari) == cd
  end
end

module Frm_form1


  def _form1_init
    self.caption = '物品貸出'
    self.move(391,100,500,550)
    addControl(VRStatic,'static4',"返却予定",256,96,100,24,1342177280)
    addControl(VRStatic,'static1',"学生番号",32,64,100,24,1342177280)
    addControl(VRStatic,'goods',"",350,64,136,24,1342177408)
    addControl(VRStatic,'static2',"連絡先",32,96,100,24,1342177280)
    addControl(VRStatic,'time_return',"",350,96,136,24,1342177408)
    addControl(VRStatic,'st_no',"",130,64,120,24,1342177408)
    addControl(VRButton,'btn_ok',"Ok",288,136,80,32,1342177280)
    addControl(VRStatic,'tel',"",130,96,120,24,1342177408)
    addControl(VRButton,'btn_cancel',"取消",384,136,80,32,1342177280)
    addControl(VRStatic,'static3',"物品",256,64,100,24,1342177280)
    addControl(VRHookedEdit,'input',"",32,16,432,24,1342177408)
    addControl(VRStatic,'name',"",32,140,160,24,1342177280)
    addControl(VRStatic,'yotei',"",32,180,430,310,1350565888)
    addControl(VRButton,'btn_change',"物品交換",192,136,80,32,1342177280)

    addControl(VRStatic,'status',"",32,118,136,24,1342177408)

  end 

  LOCAL_HOSTS = ['localhost', '127.0.0.1', '::1']

  def construct
    _form1_init
    @ini = INIT.new
    @btn_ok.disable
    @btn_change.disable

    uri = "druby://#{@ini.server_ip}:#{@ini.server_port}"

    if @ini.sc == :server
      @kashidashi = Kashidashi.new
#      p IPSocket.getaddress(Socket.gethostname)      # ocra --console でコンパイルして使うこと

      @status.caption = 'stand alone'

      Thread.new {
        while LOCAL_HOSTS.include?(IPSocket.getaddress(Socket.gethostname))
          p "#{IPSocket.getaddress(Socket.gethostname)} waiting network active"      # ocra --console でコンパイルして使うこと
          sleep 4
        end
#        p "#{uri} start"      # ocra --console でコンパイルして使うこと
        DRb.start_service(uri, @kashidashi)
        @status.caption = 'server'

      }
    else
#      p "client connect to #{uri}"      # ocra --console でコンパイルして使うこと
      @kashidashi = DRbObject.new_with_uri(uri)
      @status.caption = 'client'
    end


    @yotei.caption = @kashidashi.get_yotei
    @input.focus

    @clear_time = Time.new + 24 * 60 * 60
    clear_thread = Thread.new do
      while true
#        puts "thread active clear_time #{@clear_time} now #{Time.new}"
        sleep 30
        if Time.new > @clear_time
          @goods.caption = ''
          @st_no.caption = ''
          @tel.caption = ''
          @time_return.caption = ''
          @name.caption = ''
          @input.text = ''
        end
      end
    end

    yotei_thread = Thread.new do
      sleep 20
      while true
        @yotei.caption = @kashidashi.get_yotei
        sleep 5
      end
    end
  end 

  def input_char(ansi, keydata)
    k = ansi.chr
#    p "k #{k}"
    return if k != "\r"
    input_text = @input.text

    @clear_time = Time.new + CLEAR_AFTER_INPUT * 60       # 20141017
    @input.text = ''                                      # 20141017

    case input_text
    when /^A(\d\d\d{8}\d)A$/
      st_no = $1
      if mod10weit21?(st_no)
        @st_no.caption = st_no[2..-2]
        @name.caption = @ini.meibo[@st_no.caption]
      else
        @st_no.caption = 'C/D ERROR!'
      end
#      @clear_time = Time.new + CLEAR_AFTER_INPUT * 60
#      @input.text = ''
    when /^\d{10,11}$|^\d{3}-\d{4}-\d{4}$|^\d{2,4}-\d{2,4}-\d{4}$/
      @tel.caption = input_text
#      @clear_time = Time.new + CLEAR_AFTER_INPUT * 60
#      @input.text = ''
    when /^\d{3,4}$|^\d{1,2}:\d{2}$/
      if input_text.index(':')
        t_r = input_text
      else
        t_r = input_text[0..-3] + ':' + input_text[-2..-1]
      end
      t_r = ('0' + t_r)[-5..-1]
#      puts "t_r #{t_r}  now " + Time.new.strftime("%H:%M")
      if t_r > Time.new.strftime("%H:%M")
        @time_return.caption = t_r
      end
#      @clear_time = Time.new + CLEAR_AFTER_INPUT * 60
#      @input.text = ''
    when /^KASHI-HEN$/
#      p @btn_ok.methods.sort
      if @btn_ok.enabled?
        btn_ok_clicked
      end
    else
      if @ini.goods[input_text]
        @goods.caption = input_text
      end
    end

#    @input.text = ''

    if @goods.caption != '' and (buppin = @kashidashi.rental?(@goods.caption))
      @btn_ok.caption = '返却'
#      p buppin
      @st_no.caption = buppin.st_no
      @tel.caption = buppin.tel_no
      @time_return.caption = buppin.time_return
      @name.caption = @ini.meibo[@st_no.caption]
      @btn_ok.enable
      @btn_change.enable
    else
      @btn_ok.caption = '貸し出し'
      @btn_ok.disable
      if @st_no.caption != '' and @tel.caption != '' and @time_return.caption != '' and @goods.caption != ''
        @btn_ok.caption = '貸し出し'
        @btn_ok.enable
      end
    end

  end

  def btn_ok_clicked
#    puts 'click'
    case
    when @btn_ok.caption == '貸し出し'
      @kashidashi.kashi(Buppin.new(nil, @goods.caption, @st_no.caption, @name.caption, @tel.caption, nil, @time_return.caption))
      @btn_ok.disable
      @goods.caption = ''
      @yotei.caption = @kashidashi.get_yotei
      @clear_time = Time.new + CLEAR_AFTER_KASHIDASHI * 60
      @input.focus
    when @btn_ok.caption == '返却'
      @kashidashi.hen(@goods.caption)
      @btn_ok.disable
      @btn_change.disable
      @goods.caption = ''
      @st_no.caption = ''
      @tel.caption = ''
      @time_return.caption = ''
      @name.caption = ''
      @yotei.caption = @kashidashi.get_yotei
      @input.focus
    end
  end

  def btn_change_clicked
    @btn_change.disable
    st_no_text = @st_no.caption
    tel_text = @tel.caption
    time_return_text = @time_return.caption
    name_caption = @name.caption
    btn_ok_clicked
    @st_no.caption = st_no_text
    @tel.caption = tel_text
    @time_return.caption = time_return_text
    @name.caption = name_caption
  end

  def btn_cancel_clicked
    @btn_ok.disable
    @btn_change.disable
    @goods.caption = ''
    @st_no.caption = ''
    @tel.caption = ''
    @time_return.caption = ''
    @name.caption = ''
    @input.focus
  end
end 

VRLocalScreen.start Frm_form1
