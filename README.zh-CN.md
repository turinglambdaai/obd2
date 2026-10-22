# obd2 — SAE J1979 OBD-II services in pure Racket

[English](README.md) · **中文**

[![CI](https://github.com/turinglambdaai/obd2/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/obd2/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`obd2` 实现了 **OBD-II** 的消息层——即 SAE J1979 诊断服务（"模式"），
在主要市场销售的每一辆道路车辆都必须应答：实时传感器 PID、已存储与
待定诊断故障码、冻结帧、车辆信息与排放就绪状态。

全部以纯 Racket 实现。Mode 01 PID 表是从 Python 的
[python-OBD](https://github.com/brendan-w/python-OBD)
（0.7.3）冻结移植而来，其实时解码器同时提供了算术测试基准。DTC 文本
形式与 [uds](https://github.com/turinglambdaai/uds)
包（ISO 14229）共享，在两个诊断世界里保持完全一致的字母/数字格式。

## 安装

```
raco pkg install obd2
```

## 用法

```racket
(require obd2)

;; ask for engine RPM, then decode a positive response
(make-request #x01 #x0C)                       ; => #"\1\f"
(define r (parse-response #x01 (bytes #x41 #x0C #x0E #x70)))
(obd-response-value r)                         ; => '(924.0 . "rpm")

;; which PIDs does the vehicle support?
(decoded (pid-for #x00) (bytes #xBE #x1F #xA8 #x13))
;; => '(1 3 4 5 6 7 12 13 14 15 16 17 19 20 22 23 24)

;; stored trouble codes (mode 03)
(obd-response-value
 (parse-response #x03 (bytes #x43 #x02 #x04 #x20 #x01 #x23)))
;; => '("P0420" "P0123")

;; MIL status: on, 2 codes, spark ignition
(status-word (bytes #x82 #x07 #x65 #x04))      ; => '(#t 2 spark)

;; VIN from a service 09 response
(vin-from-response payload)
```

### 范围

- Mode 01：全部 96 个标准 PID（00-5F），按 J1979 公式实现——发动机
  负载、温度、转速、MAF、燃油修正、O2 传感器、催化器与油轨压力、
  当量比（严格按 J1979 的 /32768）、支持位图、MIL/DTC 状态字，以及
  文本表（燃油/空气状态、OBD 合规性、燃油类型）。
- Modes 02/03/04/07/09/0A：冻结帧 DTC、已存储/待定/永久 DTC 列表、
  清除故障码、带 VIN 提取的车辆信息。
- 负响应（`7F <mode> <nrc>`）以带 `negative?`/`nrc` 的
  `obd-response` 值呈现。

传输层（ISO 15765-2 / isotp）与原始 CAN 层不在范围内——把重组后的
诊断载荷喂给 `parse-response` 即可。

## 许可证

[MIT](LICENSE)。PID 表移植自 python-OBD（MIT）。
