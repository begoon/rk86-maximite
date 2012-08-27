f1 = open(ARGV[0], "rb") {|io| io.read}
f2 = open(ARGV[1], "rb") {|io| io.read}

puts f1.length
puts f2.length

i = 0
i += 1 if f1[i] == 0xE6

j = 0
j += 1 if f2[j] == 0xE6

a = 0
while true do
  if i >= f1.length then
    puts "File %s is shorter" % ARGV[0]
    break
  end
  if j >= f2.length then
    puts "File %s is shorter" % ARGV[1]
    break
  end
  s1 = "%02X" % f1[i]
  s2 = "%02X" % f2[j]
  puts "%04X: %s %s" % [a, s1, s2] if s1 != s2
  a += 1
  i += 1
  j += 1
end
