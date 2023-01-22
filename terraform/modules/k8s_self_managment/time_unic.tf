resource "time_static" "time" {
}

locals {
  time_stamp=timestamp()
  target_time_stamp= sum([tonumber(time_static.time.unix),tonumber("10")])
}