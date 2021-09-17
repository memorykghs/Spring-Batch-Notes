# 02 - Spring Batch Structure

## Spring Batch 架構大綱
| 物件 | 說明 |
| --- | --- |
Execution Context | 批次處理的執行環境，能夠將所需的餐處在處理任務的過程中進行傳遞
JobRepository | 提供處理任務的持久畫操作，儲存Job、Step執行過程中的狀態及結果
JobLauncher | 執行Job的入口，同時再啟動 Job 的時候可傳遞自定義參數
Job | Spring Batch 的一個批次處理過程，定義了批處理具體的執行邏輯，封裝整個批次處理過程的實例，由一個或多個Step組成
Step | 一個任務的具體的執行邏輯單位
Item | 一條資料記錄
ItemReader | 從資料來源讀取資料，讀取結束後會返回 `null`
ItemProcessor | 對資料進行處理，如資料清洗、轉換、過濾、校驗等，Spring Batch 提供一個 `chunk` 參數，每次任務會寫入一個 `chunk` 的數據，而 `chunk` 的數量取決於任務啟動時候的配置
ItemWriter | 寫入資料到指定目標
Chunk | 給定數量的Item集合，如讀取到chunk數量後，才進行寫操作
Tasklet | Step中具體執行邏輯，可重複執行

## Job
Job 是一個封裝整個批次處理的實體。跟其他的 Spring Project 一樣，Job 實體可以透過使用 XML 檔案或是 Java-based 的設定檔串接在一起，通常我們會稱這個檔案叫做 Job Configuration。而 Job 是整個流程最頂層的結構，示意圖如下：<br/>
![](/images/2-1.png)

在 Spring Batch 中，Job 是一個裝有 Step 實例的一個簡單的容器。一個 Job 內可以有多個流程相關聯的 Step，並透過設定來配置這個 Job 下的所有 Step 的行為，例如可以重啟 ( restartability )。Job Configuration 包含：
  * 為 Job 實例命名，每個 Job 都有自己唯一的 ID
  * 定義 Step 實例以及其順序
  * Job 是否可以重新啟動

Spring Batch 提供了一個實作 Job interface 預設的 class ( `SimpleJob` )，並創建一些標準化的功能，用來建立 Job 實例。在 Java-based 的配置檔案中，可以用 Builder 來建立我們所需的 Job 實例，例：

```java
@Bean
public Job footballJob() {
    return this.jobBuilderFactory.get("footballJob")
                     .start(playerLoad())
                     .next(gameLoad())
                     .next(playerSummarization())
                     .build();
}
```

#### JobInstance
Job 執行時期會產生一個 Job Instance ( 作業實例 )，每一次啟動 Job 都會產生一個實例。Job Instance 的來源有2種可能：
  * 根據設置的 Job Parameters 從 Job Repository 中獲取
  * 如果 Job Repository 中沒有拿到，則建立新的 Job Instance

Job Instance 之間需要靠 Job Parameters 區分。

#### Job Parameter

## 參考
* https://docs.spring.io/spring-batch/docs/4.3.x/reference/html/domain.html#job
* https://www.docs4dev.com/docs/zh/spring-batch/4.1.x/reference/domain.html#domainLanguageOfBatch
* https://blog.csdn.net/whxjason/article/details/108817354
* https://blog.csdn.net/qq_40406929/article/details/118516843
* https://blog.csdn.net/guo_xl/article/details/83444983