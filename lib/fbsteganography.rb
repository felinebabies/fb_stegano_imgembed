# coding: utf-8
require 'bundler'
Bundler.require

include Magick

module Steganography
  def embedData(embedimage, embedBytes)
    dr = Draw.new

    byteCount = 0

    (0...embedimage.rows).each do |y|
      (0...embedimage.columns).each do |x|
        pixel = embedimage.pixel_color(x, y)

        #データを1バイト取り出す
        if byteCount < embedBytes.length then
          dataByte = embedBytes[byteCount]
          byteCount += 1
        else
          dataByte = 0
        end

        #下位ビットの情報を消去
        pixel.red = pixel.red & 0b11111000
        pixel.green = pixel.green & 0b11111100
        pixel.blue = pixel.blue & 0b11111000

        #1バイト分の情報を埋め込む
        dataRed = (dataByte & 0b11100000) >> 5
        dataGreen = (dataByte & 0b00011000) >> 3
        dataBlue = (dataByte & 0b00000111)

        pixel.red = pixel.red | dataRed
        pixel.green = pixel.green | dataGreen
        pixel.blue = pixel.blue | dataBlue

        colorCode = [pixel.red, pixel.green, pixel.blue].map { |color| color.to_s(16).rjust(2, '0') }.join

        dr.fill("##{colorCode}")
        dr.point(x, y)
      end
    end

    #描画
    dr.draw(embedimage)

    return embedimage
  end

  def readData(embedimage)
    dataBytes = []

    (0...embedimage.rows).each do |y|
      (0...embedimage.columns).each do |x|
        pixel = embedimage.pixel_color(x, y)

        dataRed = pixel.red & 0b00000111
        dataGreen = pixel.green & 0b00000011
        dataBlue = pixel.blue & 0b00000111

        dataByte = (dataRed << 5) | (dataGreen << 3) | dataBlue

        dataBytes << dataByte unless dataByte == 0
      end
    end

    return dataBytes
  end

  module_function :embedData
  module_function :readData
end
