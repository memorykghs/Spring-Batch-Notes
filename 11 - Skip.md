# 10 - Skip
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
當然有可以跳過的例外，也可以設定不可跳過的例外，像上面就使用 `noSkip()` 設定遇到 ErrorInputException 時不可跳過。

那 Skip 的機制究竟是如何去決定當前紀錄的跳過與否呢?在批次處理過程中，當 Reader、Processor 及 Writer 拋出例外的時候，Spring Batch 會調用 `skip()` 方法，當沒有自訂 SkipPolicy 時預設會使用 `LimitCheckingItemSkipPolicy` 對象的內容。
> When skip is on, Spring Batch asks a skip policy whether it should skip an exception thrown by an item reader, processor, or writer. The skip policy’s decision can depend on the type of the exception and on the number of skipped items so far in the step.

```java
public FaultTolerantStepBuilder<I, O> skipPolicy(SkipPolicy skipPolicy) {
    this.skipPolicy = skipPolicy;
    return this;
}
```
<br/>

針對這些要被 skip 的批次數據，對匯該批進行 scan，跑回圈並找出具體是哪一筆資料的原因，最後進行 rollback。

不過當默認的 Policy 無法滿足業務需求時，就可以自訂 Skip 策略。

## Skip Policy
實作 `SkipPolicy` 的類別有以下 4 種，`CompositeSkipPolicy` 則是用來合併兩個 Skip Policy 規則的。 <br/>
![](/images/11-1.png)

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
根據當前 thread 中的 Skip Policy 來設置 Skip 策略。
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

#### LimitCheckingItemSkipPolicy


最後在 Step 中加入 SkipPolicy 的設定。跟前面使用 `skip()` 一樣，需要先用 `faultTolerant()` 建立 `FaulteTolerantStep`，再使用 `skipPolicy()`。一旦使用了自訂的 Skip Policy，原本的 Skip 的邏輯就沒有用了，可以快樂的刪除掉。







## 參考
* https://fangjian0423.github.io/2016/11/09/springbatch-retry-skip/ 
* https://livebook.manning.com/book/spring-batch-in-action/chapter-8/65 
* https://kknews.cc/zh-tw/tech/emye964.html