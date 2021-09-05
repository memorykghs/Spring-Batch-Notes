# 01 - Spring Batch 簡介
SpringBatch 是由 SpringSource 和 Accenture ( 埃森哲 )合作開發的，可以用來資料抽取、資料庫遷移、資料同步等。Spring Batch 只專注於處理邏輯的抽象，跟排程框架是兩回事。可以結合開源的排程框架有 quartz、cron 等等。

## Spring Batch 角色
* `job` ( 任務 ) -- 要做什麼事
* `step` ( 步驟 ) -- 完成一個任務所需的步驟

一個 `job` 可以由多個 `step` 來完成，每個 `step` 會對應到一個 `ItemReader`、`ItemProcessor` 及 `ItemWriter`。而 `job` 是透過 `JobLauncher` 來啟動，`job` 與 `step` 執行的結果和狀態都會被儲存在 `JobRepository` 中。

| 物件 | 說明 |
| --- | --- |
JobRepository | 作業倉庫，儲存Job、Step執行過程中的狀態及結果
JobLauncher | 作業執行器，是執行Job的入口
Job | 一個批次處理任務，由一個或多個Step組成
Step | 一個任務的具體的執行邏輯單位
Item | 一條資料記錄
ItemReader | 從資料來源讀資料
ItemProcessor | 對資料進行處理，如資料清洗、轉換、過濾、校驗等
ItemWriter | 	寫入資料到指定目標
Chunk | 給定數量的Item集合，如讀取到chunk數量後，才進行寫操作
Tasklet | Step中具體執行邏輯，可重複執行

## Spring Batch 步驟
1. 讀取資料 ( Reader )
2. 處理資料 ( Processor )
3. 寫資料 ( Writer )

## 異常處理機制
* 跳過
* 重試
* 重啟

## 作業方式
* 多執行緒
* 並行
* 遠端
* 分割槽

## Dependency 
```xml
<!-- MySQL database driver -->
<dependency>
    <groupId>mysql</groupId>
    <artifactId>mysql-connector-java</artifactId>
</dependency>>

<!-- jdbc -->
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-jdbc</artifactId>
</dependency>

<!-- oxm -->
<dependency>
    <groupId>org.springframework</groupId>
    <artifactId>spring-oxm</artifactId>
</dependency>

<!-- spring batch core -->
<dependency>
    <groupId>org.springframework.batch</groupId>
    <artifactId>spring-batch-core</artifactId>
</dependency>
```
Spring3.0 的一個新特性是` O/XMapper`。O/X 對映器這個概念並不新鮮，O 代表 Object，X 代表 XML。它的目的是在 Java 物件（通常是 POJO）和 XML 文件之間來回轉換。

## 參考
* https://www.gushiciku.cn/pl/2u5V/zh-tw
