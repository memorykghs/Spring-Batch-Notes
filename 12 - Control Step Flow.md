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
接下來設定參數。
```properties
```

## 參考
* https://docs.spring.io/spring-batch/docs/current/reference/html/step.html#controllingStepFlow

###### spring-boot-starter-mail
* https://www.baeldung.com/spring-email
* https://morosedog.gitlab.io/springboot-20190415-springboot27/