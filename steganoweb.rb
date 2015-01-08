# coding: utf-8

require 'bundler'
Bundler.require
require_relative 'lib/fbsteganography'

class SteganoWeb < Sinatra::Base
  register Sinatra::Reloader

  HEADERSTR = "FELINESTEGANO"

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

  #文字列埋め込み
  post '/embed' do
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

      #画像サイズを取得
      p rmImage.columns
      p rmImage.rows

      if rmImage.columns > MAXWIDTH || rmImage.columns > MAXHEIGHT then
        @mes = "画像サイズが大きすぎます<br />"
        @mes += "対応画像の最大幅は#{MAXWIDTH}ピクセルです<br />" if rmImage.columns > MAXWIDTH
        @mes += "対応画像の最大高さは#{MAXHEIGHT}ピクセルです<br />" if rmImage.columns > MAXHEIGHT
        return haml :error
      end

      maxDataLen = rmImage.columns * rmImage.rows

      #識別文字列
      headerBytes = HEADERSTR.unpack("C*")

      #書き込む文字列
      embedstr = params[:embedstr]

      embedbytes = headerBytes + embedstr.unpack("C*")

      if embedbytes.length > maxDataLen then
        @mes = "書き込む文字列が大きすぎます"
        return haml :error
      end

      #データ埋め込み
      embedData(rmImage, embedbytes)

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

      readBytes = readData(rmImage)

      #識別文字列が一致しているかを確認
      headerBytes = HEADERSTR.unpack("C*")

      if readBytes[0...headerBytes.length] != headerBytes then
        @mes = "文字列を埋め込んだ画像ではありません"
        return haml :error
      end

      strBytes = readBytes[headerBytes.length...readBytes.length]

      @readString = strBytes.pack('C*').force_encoding('utf-8')

      return haml :read
    else
      @mes = "アップロード失敗"
    end

    #失敗したらエラー画面に移行
    haml :error
  end
end
