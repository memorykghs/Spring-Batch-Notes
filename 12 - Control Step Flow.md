# 12 - Control Step Flow
到目前為止，批次處理作業中都只有一個 Step，假如今天想要先做 `Tasklet` 再跑一般的 Step，或是有多個必須連續處理的邏輯，就可以使用 `FlowStep`。除了能夠串接多個 Step 流程外，還可以依照 Step 的執行結果來決定下面要執行的 Step，這意味著我們可以在第一個 Step 執行失敗後，有另一種處理的方式。

## Sequential Flow
Step Flow 中最簡單的順序流，作完 Step A 之後依序執行 Step B 跟 Step C。<br/>
![](/images/12-1.png)

使用的方法有 `start()` 及 `next()`，程式碼如下：

```java
@Bean
public Job job() {
    return this.jobBuilderFactory.get("job")
            .start(stepA())
            .next(stepB())
            .next(stepC())
            .build();
}
```
只有當每個 Step 被執行完成且狀態為 `COMPLETE` 才會往下繼續後面的 Step。

## Conditional Flow
上面 Sequential Flow 的狀況只會有兩種可能：
1. 執行成功，往下執行後續的 Step
2. 執行失敗，整個批次處理任務中止

要是想要在批次執行失敗的時候多加一個寄信給負責人的功能，就可以使用條件式的 Step。<br/>

![](/images/12-2.png)

###### Step 1
在修改之前，先在 `pom.xml` 加入用來發送 mail 的依賴 [spring-boot-starter-mail](https://mvnrepository.com/artifact/org.springframework.boot/spring-boot-starter-mail/2.5.6)。
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-mail</artifactId>
</dependency>
```
<br/>

###### Step 2
接下來設定參數，不過在設定參數前要先到 Google 帳號產稱授權碼，相關流程可以參考這篇[建立應用程式使用密碼](https://polinwei.com/spring-boot-send-email-via-gmail/#google_vignette)。

```properties
# 信件相關
# SMTP伺服器地址
spring.mail.host=smtp.gmail.com
# SMTP伺服器端口號
spring.mail.port=123
# 發送方帳號
spring.mail.username=信箱
# 發送方密碼（授權碼）
spring.mail.password=應用程式密碼

# javaMailProperties 配置
# 開啟用戶身份驗證
spring.mail.properties.mail.smtp.auth=true
# STARTTLS：一種通信協議，具體可以搜索下
spring.mail.properties.mail.smtp.starttls.enable=true
spring.mail.properties.mail.smtp.starttls.required=true
```
<br/>

###### Step 3
先在 JobConfig 中建立寄送成功、失敗 email 的 Step 與 Tasklet。由由於 `Tasklet` 的內容不多，沒有另外獨立出單獨的 class。

```
spring.batch.springBatchExample.job
  |--DbReaderJobConfig.java // 修改
```

1. 注入 `JavaMailSender`。
    ```java
    /** 發送 email */
    @Autowired
    private  JavaMailSender mailSender;
    ```

2. 建立發送成功通知信件 Step
    ```java
    /**
    * 建立發送 success mail Step
    * @param itemReader
    * @param itemWriter
    * @param processor
    * @param transactionManager
    * @return
    */
    @Bean
    public Step sendSuccessEmailStep() {

        return stepBuilderFactory.get("Db001Step")
            .tasklet(new Tasklet() {
                
                @Override
                public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext)
                        throws Exception {

                    SimpleMailMessage mailMsg = new SimpleMailMessage();
                    mailMsg.setFrom("memorykghs@gmail.com");
                    mailMsg.setTo("memorykghs.iem01@nctu.edu.tw");
                    mailMsg.setSubject("Spring Batch 執行成功通知");
                    mailMsg.setText("成功啦!成功啦!!成功啦!!!");

                    mailSender.send(mailMsg);

                    return RepeatStatus.FINISHED;
                }
            })
            .build();
    }
    ```

3. 建立發送成功通知信件 Step
    ```java	
    /**
    * 建立發送 fail mail Step
    * @param itemReader
    * @param itemWriter
    * @param processor
    * @param transactionManager
    * @return
    */
    @Bean
    public Step sendFailEmailStep() {

        return stepBuilderFactory.get("Db001Step")
            .tasklet(new Tasklet() {
                
                @Override
                public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext)
                        throws Exception {

                    SimpleMailMessage mailMsg = new SimpleMailMessage();
                    mailMsg.setFrom("memorykghs@gmail.com");
                    mailMsg.setTo("memorykghs.iem01@nctu.edu.tw");
                    mailMsg.setSubject("Spring Batch 執行失敗通知");
                    mailMsg.setText("批次執行失敗通知測試");

                    mailSender.send(mailMsg);

                    return RepeatStatus.FINISHED;
                }
            })
            .build();
    }
    ```
<br/>

###### Step 4
最後同樣在 JobConfig 中建立 Step flow。

```
spring.batch.springBatchExample.job
  |--DbReaderJobConfig.java // 修改
```

```java
/**
 * 建立 Job
 * 
 * @param step
 * @return
 */
@Bean
public Job dbReaderJob(@Qualifier("Db001Step") Step step) {
    return jobBuilderFactory.get("Db001Job")
            .preventRestart()
            .start(step)
            .on("COMPLETED").to(sendSuccessEmailStep()) // 源頭是 Reader Step，成功發送信件
            .from(step).on("FAILED").to(sendFailEmailStep()) // 源頭也是 Reader Step，失敗也發送信件
            .end() // 表示 Step flow 結束
            .listener(new Db001JobListener())
            .build();
}
```
<br/>

整理一些比較常用的 API 及相關功能：
| 方法 | 說明 | 
| --- | --- |
| `start(Step step)` | 傳入一個 Step，然後回傳 `StepBuilder` 物件，當後面沒有接其他 flow 相關的方法時，代表要執行的唯一 Step；在 Step flow 中則代表 Step 的源頭。 | 
| `on(String pattern)` | 傳入 String 型別的物件，在過程中會依照給予的條件判斷當前步驟的執行結果要往哪個分支進行下去。其他比對的特殊規則可以參考[官網](https://docs.spring.io/spring-batch/docs/current/reference/html/step.html#conditionalFlow)。 | 
| `to(Step step)` | 用來設定判斷後下一步要執行的 Step。 |
| `from(Step step)` | 從 `start()` 方法的 Step 註冊另外一條分支，並設定要執行的 Step。 |

大致的流程如下圖。<br/>
![](/images/12-3.png)

## 參考
* https://docs.spring.io/spring-batch/docs/current/reference/html/step.html#controllingStepFlow

###### spring-boot-starter-mail
* https://www.baeldung.com/spring-email
* https://morosedog.gitlab.io/springboot-20190415-springboot27/
* https://polinwei.com/spring-boot-send-email-via-gmail/
* https://www.gushiciku.cn/pl/2Md9/zh-tw
