# 14 - Skip
Skip 指的是當批次處理過程當中出現錯誤或是拋出例外時，我們不想要因為這些問題中斷整個批次處理，因為程式被中斷時很有可能遺失紀錄在整個執行環境中 Spring Batch 的相關參數資訊，如 StepExecution、JobExecution 等等。這時候就可以設定 Skip 規則讓程式在出現錯誤時，先跳過繼續往下。

回憶一下前面建立的 Step 的程式碼：
```java
@Bean
@Qualifier("DbToFile")
private Step fileReaderStep(ItemReader<BookInfoDto> itemReader, JpaTransactionManager jpaTransactionManager) {
    return stepBuilderFactory.get("BCHBORED001Step")
        .transactionManager(jpaTransactionManager)
        .<BookInfoDto, BookInfoDto> chunk(FETCH_SIZE)
        .reader(itemReader)
        .faultTolerant()
        .skip(ErrorInputException.class)
        .skip(DataNotFoundException.class)
        .skipLimit(Integer.MAX_VALUE)
        .build();
}
```

在設定 Step 時，通常我們會加入 `skip()` 來指定遇到什麼類型的 Exception 要跳過；而 `skipLimit()` 則是針對跳過的次數做設定。在使用這兩個方法前，一定要加上 `faultTolerant()` 產生 `FaulteTolerantStep`，因為 `skip()` 及 `skipLimit()` 是其類別中的方法。

`skip()` 與 `skipLimit()` 必須同時存在，否則會報錯：
```
org.springframework.batch.core.step.skip.SkipLimitExceededException: Skip limit of '0' exceeded
```
<br/>

當然有可以跳過的例外，也可以設定不可跳過的例外，像上面就使用 `noSkip()` 設定遇到 ErrorInputException 時不可跳過。

```java
@Bean
@Qualifier("DbToFile")
private Step fileReaderStep(ItemReader<BookInfoDto> itemReader, JpaTransactionManager jpaTransactionManager) {
    return stepBuilderFactory.get("BCHBORED001Step")
        .transactionManager(jpaTransactionManager)
        .<BookInfoDto, BookInfoDto> chunk(FETCH_SIZE)
        .reader(itemReader)
        .faultTolerant()
        .noSkip(ErrorInputException.class) // 不可跳過
        .skip(DataNotFound.class)
        .skipLimit(Integer.MAX_VALUE)
        .build();
}
```

那 Skip 的機制究竟是如何去決定當前紀錄的跳過與否呢?在批次處理過程中，當 Reader、Processor 及 Writer 拋出例外的時候，Spring Batch 會調用 `skip()` 方法，當沒有自訂 SkipPolicy 時預設會使用 `LimitCheckingItemSkipPolicy` 對象的內容。
> When skip is on, Spring Batch asks a skip policy whether it should skip an exception thrown by an item reader, processor, or writer. The skip policy’s decision can depend on the type of the exception and on the number of skipped items so far in the step.

```java
public FaultTolerantStepBuilder<I, O> skipPolicy(SkipPolicy skipPolicy) {
    this.skipPolicy = skipPolicy;
    return this;
}
```
<br/>

針對這些要被 skip 的批次數據，會對該批進行 scan，跑回圈並找出具體是哪一筆資料的原因，最後進行 rollback。

不過當默認的 Policy 無法滿足業務需求時，就可以自訂 Skip 策略。

## Skip Policy
實作 `SkipPolicy` 的類別有以下 4 種，`CompositeSkipPolicy` 則是用來合併兩個 Skip Policy 規則的。 <br/>
![](/images/14-1.png)

| Skip policy class[*] | 說明 |
| --- | --- |
| `AlwaysSkipItemSkipPolicy` | 不管丟出例外或是設定的 skip 的數量是否達到上限，全部 skip 掉 |
| `NeverSkipItemSkipPolicy` | 遇到任何情況都不 skip |
| `LimitCheckingItemSkipPolicy` | Skips items depending on the exception thrown and the total number of skipped items; this is the default implementation |
| `ExceptionClassifierSkipPolicy` | 依照當前丟出來的例外判斷，將 Skip 的策略委派給其他的 Skip Policy |
<br/>

#### AlwaysSkipItemSkipPolicy
從下面的程式碼可以發現，不管發生什麼例外 `shouldSkip()` 方法都回傳 `true`，代表每一筆都跳過 ٩(●ᴗ●)۶。
```java
public class AlwaysSkipItemSkipPolicy implements SkipPolicy {

	@Override
	public boolean shouldSkip(Throwable t, int skipCount) {
		return true;
	}

}
```

#### LimitCheckingItemSkipPolicy
與 `AlwaysSkipItemSkipPolicy` 相反，任何例外都不會跳過 ╮(￣_￣)╭。
```java
public class NeverSkipItemSkipPolicy implements SkipPolicy{

	@Override
	public boolean shouldSkip(Throwable t, int skipCount) {
		return false;
	}

}
```

#### ExceptionClassifierSkipPolicy
可以設定跳過次數的策略，也是 Spring Batch 預設的 Skip Policy。
```java
@Override
public boolean shouldSkip(Throwable t, int skipCount) {
    if (skippableExceptionClassifier.classify(t)) {
        if (skipCount < skipLimit) {
            return true;
        }
        else {
            throw new SkipLimitExceededException(skipLimit, t);
        }
    }
    else {
        return false;
    }
}
```

#### CompositeSkipPolicy
可以組合多個 Skip Policy 在出現例外時，依這些 Policy 的規則決定是否跳過。對於組合策略，只要有一個滿足 skip 的條件，那麼就會整個 skip。
```java
public class CompositeSkipPolicy implements SkipPolicy {

	private SkipPolicy[] skipPolicies;

	public CompositeSkipPolicy() {
		this(new SkipPolicy[0]);
	}

	public CompositeSkipPolicy(SkipPolicy[] skipPolicies) {
		this.skipPolicies = skipPolicies;
	}

	public void setSkipPolicies(SkipPolicy[] skipPolicies) {
		this.skipPolicies = skipPolicies;
	}

	@Override
	public boolean shouldSkip(Throwable t, int skipCount) throws SkipLimitExceededException {
		for (SkipPolicy policy : skipPolicies) {
			if (policy.shouldSkip(t, skipCount)) {
				return true;
			}
		}
		return false;
	}

}
```

## Custom Skip Policy
根據當前 thread 中的 Skip Policy 來設置 Skip 策略，Spring Batch 框架提供 `SkipPolicy` 介面並定義一些行為，所以只要實作此介面即可。
```java
/**
 * Consult the classifier and find a delegate policy, and then use that to
 * determine the outcome.
 *
 * @param t the throwable to consider
 * @param skipCount the current skip count
 * @return true if the exception can be skipped
 * @throws SkipLimitExceededException if a limit is exceeded
 */
@Override
public boolean shouldSkip(Throwable t, int skipCount) throws SkipLimitExceededException {
    return classifier.classify(t).shouldSkip(t, skipCount);
}
```
可以看到上面的 source code 中，必須覆寫 `shouldSkip()` 方法，並回傳代表是否跳過的 boolean 值。

那麼接下來我們就來實作吧~假設今天遇到價差太大的我們就懷疑他有哄抬價格的嫌疑，不可被跳過；如果是查無資料的話在允許的出錯範圍內都可以被跳過。

```
spring.batch.springBatchExample.job
  |--dbReaderJobConfig.java // 修改
spring.batch.springBatchExample.process
  |--DBItemProcessor.java // 修改
spring.batch.springBatchExample.skipPolicy // 新增
  |--CustomSkipPolicy.java // 新增
```

* `CustomSkipPolicy.java`
```java
public class CustomSkipPolicy implements SkipPolicy {

    /** 設定可容忍錯誤的次數 */
    private static final int MAX_SKIP_COUNT = 1;

    @Override
    public boolean shouldSkip(Throwable t, int skipCount) throws SkipLimitExceededException {

        // 可以跳過 DataNotFoundException
        if (t instanceof DataNotFoundException && skipCount < MAX_SKIP_COUNT) {
            return true;
        }

        // RangeLimitExcpetion 不可被跳過
        if (t instanceof RangeLimitExcpetion && skipCount < MAX_SKIP_COUNT) {
            return false;
        }

        return false;
    }
}
```

接下來我們在 ItemProcess 內增加判斷邏輯。
* `DBItemProcessor.java`
```java
@Component
public class DBItemProcessor implements ItemProcessor<Cars, CarsDto> {

    private static final BigDecimal defaultSpread = new BigDecimal("50");

    @Override
    public CarsDto process(Cars item) throws Exception {

        // 計算每一廠牌汽車底價及售價價差
        CarsDto carsDto = new CarsDto();
        carsDto.setManufacturer(item.getManufacturer());
        carsDto.setType(item.getType());

        BigDecimal spread = item.getPrice().subtract(item.getMinPrice());
        carsDto.setSpread(spread);

        // 判斷價差是否過大
        if (defaultSpread.compareTo(spread) == -1) {
            throw new RangeLimitExcpetion();

        } else if (defaultSpread.compareTo(spread) == 0) {
            throw new DataNotFoundException();
        }

        return carsDto;
    }
}
```

以下省略部分程式碼，只放要修改的 Step 部分。跟前面使用 `skip()` 一樣，需要先用 `faultTolerant()` 建立 `FaulteTolerantStep`，再使用 `skipPolicy()`。一旦使用了自訂的 Skip Policy，原本的 Skip 的邏輯就沒有用了，可以快樂的刪除掉。
* `dbReaderJobConfig.java`
```java
@Bean("Db001Step")
public Step dbReaderStep(@Qualifier("Db001JpaReader") ItemReader<Cars> itemReader, @Qualifier("Db001FileWriter") ItemWriter<CarsDto> itemWriter,
        ItemProcessor<Cars, CarsDto> processor, JpaTransactionManager transactionManager) {

    return stepBuilderFactory.get("Db001Step")
            .transactionManager(transactionManager)
            .<Cars, CarsDto>chunk(FETCH_SIZE)
            .faultTolerant()
            .skipPolicy(new CustomSkipPolicy()) // 新增
            .reader(itemReader)
            .processor(processor)
            .writer(itemWriter)
            .listener(new Db001StepListener())
            .listener(new Db001ReaderListener())
            .listener(new Db001WriterListener())
            .build();
	}
```

## 參考
* https://fangjian0423.github.io/2016/11/09/springbatch-retry-skip/ 
* https://livebook.manning.com/book/spring-batch-in-action/chapter-8/65 
* https://kknews.cc/zh-tw/tech/emye964.html
* https://www.baeldung.com/spring-batch-skip-logic