[Русская версия](COST_MODEL_RU.md) · [Eng version](COST_MODEL.md) · [Versión en español](COST_MODEL_ES.md) · [Version française](COST_MODEL_FR.md) · [Deutsche Version](COST_MODEL_DE.md) · [ქართული ვერსია](COST_MODEL_GE.md) · [日本語版](COST_MODEL_JP.md)

# EKS 叢集成本模型：估算範本

[課程目錄](README_TW.md) · [第 43 章](43/tw.md) · [術語表](GLOSSARY_TW.md)

這是第 43 章的工作表：成本結構相同，但改以表格和公式呈現，讓工程師能據此建立
自己叢集的估算。本文件不含新內容。

## 使用方式

- 此表**不含價格**。費率取決於區域，且其變動與過時速度快於課程，因此「費率（自行填寫）」欄位刻意留白。
- 請在 AWS Pricing Calculator 依您的區域取得費率並填入空白欄位；若要取得已運行叢集的實際數據，請從 Cost and Usage Report 取得（第 43 章）。
- 此範本的價值不在數字的精確度，而在項目清單的完整性：它避免您遺漏會出現在帳單上、卻未納入估算的項目。
- 請做兩次估算：right-sizing **之前**與**之後**。兩次執行的差額，才是工程決策可量測的效果，而非節省承諾。
- 全表請維持相同單位（月內小時數、GB 與 GiB），否則各列無法相加。
- 每當變更節點購買模式、增加 AZ、啟用新類型的 logs，或變更任何 egress 拓撲時，請重新執行本表。

## 成本項目

| 項目 | 取決於 | 單位 | 費率（自行填寫） | 章節 |
|---|---|---|---|---|
| 叢集 control plane | 叢集數量、運行時間 | 叢集小時 |  | [02](02/tw.md) |
| extended support 加價 | 處於 standard support 以外的版本 | 叢集小時 |  | [38](38/tw.md) |
| EC2 節點 | instance 類型、節點數量、購買模式 | instance 小時 |  | [09](09/tw.md) |
| Auto Mode 管理加價 | Auto Mode 管理的 instances | instance 小時 |  | [09](09/tw.md) |
| Fargate：vCPU | Pod 的 CapacityProvisioned、生命週期 | vCPU 小時 |  | [15](15/tw.md) |
| Fargate：記憶體 | Pod 的 CapacityProvisioned、生命週期 | GB 小時 |  | [15](15/tw.md) |
| EBS volumes | volume 類型、容量、設定的 IOPS 與 throughput | GiB 月 |  | [23](23/tw.md) |
| EBS snapshots | 已擷取資料的容量、保留期間 | GiB 月 |  | [23](23/tw.md) |
| NAT Gateway：運行 | NAT 數量（每個 AZ 一個）、存在時間 | NAT 小時 |  | [31](31/tw.md) |
| NAT Gateway：處理 | Pod egress、映像檔 pull、AWS API 呼叫 | GB |  | [31](31/tw.md) |
| Cross-AZ 流量 | 可用區之間的 east-west 流量、呼叫其他 AZ 的資料庫 | GB |  | [31](31/tw.md) |
| 對網際網路的傳出流量 | 對客戶的回應、向外傳輸 | GB |  | [31](31/tw.md) |
| Interface endpoints (PrivateLink) | endpoint 數量、處理量 | endpoint 小時與 GB |  | [31](31/tw.md) |
| Logs：擷取（ingestion） | 接收的 Pod 與 control plane logs 容量 | GB |  | [34](34/tw.md) |
| Logs：儲存 | 指定 retention 下的容量 | GB 月 |  | [34](34/tw.md) |
| 負載平衡器（NLB、ALB） | 負載平衡器數量、處理量 | 小時與資料量 |  | [26](26/tw.md) |

S3 與 DynamoDB 的 gateway endpoints 不需要在此表另列：它們免費，但會將流量從付費 NAT
導走，因此會影響「NAT Gateway：處理」一列（第 31 章）。

## 通用公式

```text
符號說明：HOURS 為計算月份的小時數，RATE_* 為上表的費率，
所有用量數值都應取自 metrics 與 billing，而非設計規劃。

control_plane = CLUSTERS * HOURS * RATE_CP
              + CLUSTERS_EXT * HOURS * RATE_CP_EXT_DELTA
# CLUSTERS_EXT 是處於 extended support 版本的叢集：這是加在一般
# 叢集每小時費用之上的加價，並非相同的費率（第 38 章）。

nodes = 各集區 P 的總和：NODES[P] * HOURS[P] * RATE_INSTANCE[P, 購買模式]
# 購買模式：On-Demand、Spot、Reserved 或 Savings Plans 覆蓋（第 43 章）。

auto_mode = nodes(Auto Mode 集區)                          # EC2 部分
          + MANAGED_INSTANCES * HOURS * RATE_AM_MGMT       # 管理加價
# **務必注意**：Reserved Instances 與 Savings Plans 僅降低 EC2 部分。
# Auto Mode 的管理加價不適用這些折扣，並會在帳單中作為獨立項目存在
# （第 09 章）。EKS control plane 的每小時費用也不適用 Compute Savings Plans
# （第 43 章）。

fargate = 各 Pod 的總和：VCPU_PROV * LIFETIME_H * RATE_VCPU
        + MEM_PROV_GB * LIFETIME_H * RATE_MEM
# VCPU_PROV 與 MEM_PROV_GB 是 CapacityProvisioned annotation 所給予的組合，
# 即向上取整後的 requests，而非 requests 本身（第 15 章）。

commit_base = BASELINE_COMPUTE - SPOT_SUSTAINED
# BASELINE_COMPUTE 應在 right-sizing **之後**計算，否則承諾的是空白容量。
# SPOT_SUSTAINED 是可持續達成的 Spot 比例，而非規劃中的比例：Savings Plans
# 不涵蓋 Spot，每小時的承諾不會在小時之間轉移，不足使用的部分每小時都會失效，
# 而 fallback 至 On-Demand 會讓部分用量回到承諾之下
# （第 43 與 13 章）。應根據實際 utilization 與 coverage 重新檢視承諾。

nat = NAT_COUNT * HOURS * RATE_NAT_HOUR
    + PROCESSED_GB * RATE_NAT_GB
# 兩個彼此獨立的部分：NAT 存在本身的費用，以及每個處理 GB 的費用。

cross_az = CROSS_AZ_GB * RATE_CROSS_AZ
# 兩個方向都會計費：CROSS_AZ_GB 同時包含請求與回應（第 31 章）。

storage = 各 volume 的總和：SIZE_GIB * RATE_VOLUME[類型]
        + SNAPSHOT_GIB * RATE_SNAPSHOT
# 付費的是設定的 volume 大小，而不是檔案系統內實際已使用的容量。

logs = INGEST_GB * RATE_INGEST + STORED_GB * RATE_STORAGE
# INGEST_GB 是接收的資料量：通常它才是主要項目（第 34 章）。

total_month = control_plane + nodes + auto_mode + fargate
            + nat + cross_az + egress_internet + storage + logs
            + endpoints + load_balancers
```

## 常被遺漏的項目

- **Auto Mode 加價。** 此為帳單中 EC2 費率之上的獨立項目，折扣模型不會影響它；比較 Auto Mode 與自建堆疊時，必須明確計算它（第 09 章）。
- **extended support 是加價。** 使用過時版本的叢集每小時運行成本較高，而非相同；在估算中它是獨立的加項（第 38 章）。
- **雙向 Cross-AZ。** 一個可用區的服務呼叫另一個可用區的資料庫時，要為交換流量付費，而非只為請求付費；必須計算兩個方向（第 31 章）。
- **NAT 收費兩次。** NAT 存在期間會收取每小時費用，且不論此費用，還會對每個處理的 GB 收費；通常遺漏的是第二部分（第 31 章）。
- **Logs 的主要費用是擷取。** 縮短 retention 只影響儲存，節省有限；應調整收集間隔、log 等級與序列篩選（第 34 章）。
- **遺忘的 volumes 與 snapshots。** PVC 已刪除，volume 卻還在；snapshots 多年持續累積。這是只有在 billing 中才看得見的無聲流失（第 23 章）。
- **已刪除 Service 遺留的負載平衡器。** Service 不是透過 Kubernetes 移除，NLB 或 ALB 便會繼續存在並計費（第 26 章）。
- **Idle 容量。** 您支付的是保留的 requests，而非實際使用量：requested 與 used 的差距是已付費的空白容量，再乘上 replicas 數量（第 43 章）。

## 最佳化順序

1. **Right-size 與 bin-pack**：使 requests 貼近實際用量，並讓 consolidation 壓實節點（第 43、14、12 章）。
2. **對穩定 baseline 做承諾**：在縮減之後，為維持數月的用量購買 Savings Plans（第 43 章）。
3. **將彈性工作負載使用 Spot**：可中斷的工作負載改用 Spot，並跨類型與可用區進行分散（第 13 章）。
4. **流量、logs 與儲存**：S3 的 gateway endpoint、每個可用區的 NAT、源頭的 logs 容量、volumes 與 snapshots（第 31、34、23 章）。

順序必須如此，因為每個後續步驟都套用到前一個步驟所縮減的基礎上：對膨脹容量做承諾或使用 Spot，就是固定支付空白容量的費用。

## 範本的邊界

- 本表無法取代用於預測的 AWS Pricing Calculator 與用於實際數據的 Cost and Usage Report：它提供項目清單與公式，數字則來自這兩者。
- 叢集以外的應用服務（資料庫、佇列、快取、供應用資料使用的 S3）不在此計算，雖然它們包含在產品帳單中。
- 按團隊與 namespace 的分攤應由第 43 章的 allocation 工具完成，而非此表：此表面向整個叢集，而非其內部各方的支出。
- 本表將 shared costs（control plane、system namespaces、idle）顯示為叢集項目；將其分配至團隊的規則應另行選擇（第 43 章）。
- 本表不建模與 AWS 的合約折扣及承諾的套用順序：只有實際 billing 才能看見它們。