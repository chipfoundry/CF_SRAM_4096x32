#!/usr/bin/env ruby
# Check that one connected met1 cluster does not touch two signal pins on the
# same CF_SRAM_1024x32 instance. Run through KLayout's Ruby interpreter.

gds = ENV.fetch("GDS")
lef = ENV.fetch("MACRO_LEF")
top_name = ENV.fetch("TOP", "CF_SRAM_4096x32")
macro_name = ENV.fetch("MACRO", "CF_SRAM_1024x32")

pins = {}
in_macro = false
pin = nil
use = "SIGNAL"
layer = nil

File.foreach(lef) do |line|
  words = line.strip.split
  if words[0] == "MACRO"
    in_macro = words[1] == macro_name
  elsif in_macro && words[0] == "PIN"
    pin = words[1]
    pins[pin] = { use: "SIGNAL", rects: [] }
  elsif in_macro && pin && words[0] == "USE"
    pins[pin][:use] = words[1]
  elsif in_macro && pin && words[0] == "LAYER"
    layer = words[1].downcase
  elsif in_macro && pin && words[0] == "RECT" && layer == "met1"
    pins[pin][:rects] << words[1, 4].map(&:to_f)
  elsif in_macro && pin && words[0] == "END" && words[1] == pin
    pin = nil
    layer = nil
  elsif in_macro && words[0] == "END" && words[1] == macro_name
    in_macro = false
  end
end

signal_pins = pins.select do |_name, data|
  !%w[POWER GROUND].include?(data[:use]) && !data[:rects].empty?
end
abort("No met1 signal-pin rectangles found for #{macro_name} in #{lef}") if signal_pins.empty?

layout = RBA::Layout.new
layout.read(gds)
top = layout.cell(top_name)
abort("Top cell #{top_name} not found in #{gds}") unless top
met1_index = layout.find_layer(68, 20)
abort("GDS layer 68/20 (met1) not found in #{gds}") if met1_index.nil?

instances = []
top.each_inst do |inst|
  next unless inst.cell.name == macro_name
  abort("Arrayed #{macro_name} instances are not supported") if inst.is_regular_array?

  transformed_pins = []
  signal_pins.each do |name, data|
    data[:rects].each do |coords|
      dbu_coords = coords.map { |value| (value / layout.dbu).round }
      box = RBA::Box.new(*dbu_coords).transformed(inst.trans)
      transformed_pins << [name, box]
    end
  end
  instances << [inst.to_s, transformed_pins]
end

abort("Expected 4 #{macro_name} instances, found #{instances.length}") unless instances.length == 4

met1 = RBA::Region.new(top.begin_shapes_rec(met1_index)).merged
shorts = []
met1.each_merged do |polygon|
  cluster = RBA::Region.new(polygon)
  instances.each do |instance_name, instance_pins|
    touched = instance_pins.map do |pin_name, box|
      pin_name unless (cluster & RBA::Region.new(box.enlarged(1))).is_empty?
    end.compact.uniq
    shorts << [instance_name, touched] if touched.length > 1
  end
end

unless shorts.empty?
  warn("met1 signal-pin short check FAILED:")
  shorts.each { |instance, touched| warn("  - #{instance}: #{touched.sort.join(', ')}") }
  exit(1)
end

puts(
  "met1 signal-pin short check passed: " \
  "#{instances.length} instances, #{signal_pins.length} met1 signal pins per instance."
)
