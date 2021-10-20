# 10 - Skip

回憶一下前面建立的 Step 的程式碼：
```java
@Bean
@Qualifier("DbToFile")
private Step fileReaderStep(ItemReader<BookInfoDto> itemReader, JpaTransactionManager jpaTransactionManager) {
    return stepBuilderFactory.get("BCHBORED001Step")
        .transactionManager(jpaTransactionManager)
        .<BookInfoDto, BookInfoDto> chunk(FETCH_SIZE)
        .reader(itemReader).faultTolerant()
        .skip(Exception.class)
        .skipLimit(Integer.MAX_VALUE)
        .build();
}
```
8.2. Skipping instead of failing
Sometimes errors aren’t fatal: a job execution shouldn’t stop when something goes wrong. In the online store application, when importing products from a flat file, should you stop the job execution because one line is in an incorrect format? You could stop the whole execution, but the job wouldn’t insert the subsequent lines from the file, which means fewer products in the catalog and less money coming in! A better solution is to skip the incorrectly formatted line and move on to the next line.

Whether or not to skip items in a chunk-oriented step is a business decision. The good news is that Spring Batch makes the decision of skipping a matter of configuration; it has no impact on the application code. Let’s see how to tell Spring Batch to skip items and then how to tune the skip policy.

8.2.1. Configuring exceptions to be skipped
Recall that the import products job reads products from a flat file and then inserts them into the database. It would be a shame to stop the whole execution for a couple of incorrect lines in a file containing thousands or even tens of thousands of lines. You can tell Spring Batch to skip incorrect lines by specifying which exceptions it should ignore. To do this, you use the skippable-exception-classes element, as shown in the following listing.


8.2.2. Configuring a SkipPolicy for complete control
Who decides if an item should be skipped or not in a chunk-oriented step? Spring Batch calls the skip policy when an item reader, processor, or writer throws an exception, as figure 8.2 shows. When using the skippable-exception-classes element, Spring Batch uses a default skip policy implementation (LimitCheckingItemSkipPolicy), but you can declare your own skip policy as a Spring bean and plug it into your step. This gives you more control if the skippable-exception-classes and skip-limit pair isn’t enough.

> When skip is on, Spring Batch asks a skip policy whether it should skip an exception thrown by an item reader, processor, or writer. The skip policy’s decision can depend on the type of the exception and on the number of skipped items so far in the step.


Skip policy implementations provided by Spring Batch
| Skip policy class[*] | Description |
| --- | --- |
| `LimitCheckingItemSkipPolicy` | Skips items depending on the exception thrown and the total number of skipped items; this is the default implementation |
| `ExceptionClassifierSkipPolicy` | Delegates skip decision to other skip policies depending on the exception thrown |
| `AlwaysSkipItemSkipPolicy` | Always skips, no matter the exception or the total number of skipped items |
| `NeverSkipItemSkipPolicy` | Never skips |

## 參考
* https://fangjian0423.github.io/2016/11/09/springbatch-retry-skip/ 
* https://livebook.manning.com/book/spring-batch-in-action/chapter-8/65 