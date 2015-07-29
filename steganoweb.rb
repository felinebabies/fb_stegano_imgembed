# coding: utf-8

require 'bundler'
Bundler.require
require_relative 'lib/fbsteganography'

def to_byte_array(num)
  result = []
  begin
    result << (num & 0xff)
    num >>= 8
  end until (num == 0 || num == -1) && (result.last[7] == num[7])
  result.reverse
end

def to_2byte_array(num)
    array = to_byte_array(num)
    if array.length < 2 then
      array << 0
      array.reverse!
    end

    return array[-2, 2]
end

def byteArrayToInt(byteArray)
  num = 0
  byteArray.each do |byte|
    num <<= 8
    num += byte
  end

  return num
end

class SteganoWeb < Sinatra::Base
  register Sinatra::Reloader

  HEADERSTR = "FELINEIMGEMB"

  MAXWIDTH = 800
  MAXHEIGHT = 800

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html
  end

  #ページ表示
  get '/' do
    @maxWidth = MAXWIDTH
    @maxHeight = MAXHEIGHT
    haml :index
  end

  #画像埋め込み
  post '/embed' do
    if params[:file] && params[:embfile] then
      imageBlob = params[:file][:tempfile].read
      embimgBlob = params[:embfile][:tempfile].read

      begin
        rmImage = Image.from_blob(imageBlob)[0]
      rescue
        @mes = "埋め込み先画像を読み取れませんでした"
        return haml :error
      end

      begin
        embImage = Image.from_blob(embimgBlob)[0]
      rescue
        @mes = "埋め込み画像を読み取れませんでした"
        return haml :error
      end

      #元のファイル名を取得
      postedFileName = params[:file][:filename]

      #画像サイズを取得
      p "base image size col: #{rmImage.columns} row: #{rmImage.rows}"
      p "embed image size col: #{embImage.columns} row: #{embImage.rows}"

      if rmImage.columns > MAXWIDTH || rmImage.columns > MAXHEIGHT then
        @mes = "埋め込み先画像サイズが大きすぎます<br />"
        @mes += "対応画像の最大幅は#{MAXWIDTH}ピクセルです<br />" if rmImage.columns > MAXWIDTH
        @mes += "対応画像の最大高さは#{MAXHEIGHT}ピクセルです<br />" if rmImage.columns > MAXHEIGHT
        return haml :error
      end

      maxDataLen = rmImage.columns * rmImage.rows

      embImgPixels = embImage.columns * embImage.rows

      if embImgPixels > (maxDataLen / 3) then
        @mes = "埋め込む画像が大きすぎます。埋め込み画像の面積は、埋め込み先の1/3までです。"
        return haml :error
      end

      #識別文字列
      headerBytes = HEADERSTR.unpack("C*")

      #埋め込み画像をバイト列化する
      embedbytes = []
      embedbytes += headerBytes #ヘッダ
      embedbytes += to_2byte_array(embImage.columns) #埋め込み画像幅
      embedbytes += to_2byte_array(embImage.rows) #埋め込み画像高さ
      embedbytes += to_2byte_array(params[:xpos].to_i) #埋め込みx座標
      embedbytes += to_2byte_array(params[:ypos].to_i) #埋め込みy座標

      p "embed header = #{embedbytes.join(" ")}"

      embedbytes += Steganography.imageToByteArray(embImage) #データ本体

      if embedbytes.length > maxDataLen then
        @mes = "埋め込む画像が大きすぎます"
        return haml :error
      end

      #データ埋め込み
      Steganography.embedData(rmImage, embedbytes)

      #フォーマットをPNGに変換する
      if rmImage.format != "PNG" then
        rmImage.format = "PNG"
      end

      #成功したらファイルをダウンロードさせる
      attachment "#{File.basename(postedFileName, ".*")}_embedded.png"
      return rmImage.to_blob
    else
      @mes = "アップロード失敗"
    end

    #失敗したらエラー画面に移行
    haml :error
  end

  #画像から読み取り
  post '/read' do
    if params[:file]
      imageBlob = params[:file][:tempfile].read
      begin
        rmImage = Image.from_blob(imageBlob)[0]
      rescue
        @mes = "画像を読み取れませんでした"
        return haml :error
      end

      #元のファイル名を取得
      postedFileName = params[:file][:filename]

      readBytes = Steganography.readData(rmImage)

      #識別文字列が一致しているかを確認
      headerBytes = HEADERSTR.unpack("C*")

      if readBytes[0...headerBytes.length] != headerBytes then
        @mes = "文字列を埋め込んだ画像ではありません"
        return haml :error
      end

      #画像サイズを取り出す
      embImgWidth = byteArrayToInt(readBytes[headerBytes.length, 2])
      embImgHeight = byteArrayToInt(readBytes[headerBytes.length + 2, 2])
      embImgXpos = byteArrayToInt(readBytes[headerBytes.length + 4, 2])
      embImgYpos = byteArrayToInt(readBytes[headerBytes.length + 6, 2])

      p "embImgWidth: #{embImgWidth} embImgHeight: #{embImgHeight}"
      p "embImgXpos: #{embImgXpos} embImgYpos: #{embImgYpos}"

      dataBytes = readBytes[(headerBytes.length + 8)...readBytes.length]

      #画像にデータ上書き
      Steganography.overWriteImage(rmImage, dataBytes, embImgWidth, embImgHeight, embImgXpos, embImgYpos)

      #成功したらファイルをダウンロードさせる
      attachment "#{File.basename(postedFileName, ".*")}_overwrite.png"
      return rmImage.to_blob
    else
      @mes = "アップロード失敗"
    end

    #失敗したらエラー画面に移行
    haml :error
  end
end
