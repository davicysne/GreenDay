import { deflateSync } from 'node:zlib'
import { writeFileSync } from 'node:fs'

const width = 512, height = 512
const rgba = Buffer.alloc(width * height * 4)
const insideRoundedRect = (x, y, radius = 148) => {
  const cx = Math.max(radius, Math.min(width - radius, x))
  const cy = Math.max(radius, Math.min(height - radius, y))
  return (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2
}
const insideLeaf = (x, y) => {
  const dx = (x - 267) / 142, dy = (y - 250) / 125
  return dx * dx + dy * dy < 1 && x + y > 300 && x < 382 && y < 385
}
for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
  const i = (y * width + x) * 4
  let color = insideRoundedRect(x, y) ? [23, 79, 45, 255] : [0, 0, 0, 0]
  if (insideLeaf(x, y)) color = [245, 251, 246, 255]
  const lineY = 408 - .69 * x
  if (x > 164 && x < 350 && Math.abs(y - lineY) < 10) color = [155, 210, 168, 255]
  rgba.set(color, i)
}
const raw = Buffer.alloc((width * 4 + 1) * height)
for (let y = 0; y < height; y++) {
  raw[y * (width * 4 + 1)] = 0
  rgba.copy(raw, y * (width * 4 + 1) + 1, y * width * 4, (y + 1) * width * 4)
}
const crcTable = Array.from({ length: 256 }, (_, n) => {
  let c = n
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
  return c >>> 0
})
const crc32 = data => {
  let c = 0xffffffff
  for (const byte of data) c = crcTable[(c ^ byte) & 255] ^ (c >>> 8)
  return (c ^ 0xffffffff) >>> 0
}
const chunk = (type, data) => {
  const name = Buffer.from(type), size = Buffer.alloc(4), crc = Buffer.alloc(4)
  size.writeUInt32BE(data.length); crc.writeUInt32BE(crc32(Buffer.concat([name, data])))
  return Buffer.concat([size, name, data, crc])
}
const header = Buffer.alloc(13)
header.writeUInt32BE(width, 0); header.writeUInt32BE(height, 4); header.set([8, 6, 0, 0, 0], 8)
const png = Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]), chunk('IHDR', header), chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0))])
writeFileSync(new URL('../public/favicon.png', import.meta.url), png)
