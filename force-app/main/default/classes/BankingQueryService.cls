public class BankingQueryService {
    
    public class QueryResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Object data;
        
        public QueryResult(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }
    
    public class AccountSummary {
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String accountType;
        @AuraEnabled public Decimal balance;
        @AuraEnabled public String accountStatus;
        @AuraEnabled public String holderName;
        @AuraEnabled public Date openingDate;
    }
    
    public class TransactionRecord {
        @AuraEnabled public String transactionId;
        @AuraEnabled public String type;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public DateTime transactionDate;
        @AuraEnabled public String description;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal runningBalance;
    }
    
    // Get account balance
    @AuraEnabled
    public static QueryResult getAccountBalance(String accountNumber, String sessionToken) {
        try {
            // Verify session
            if (!BankingOTPService.isSessionValid(accountNumber, sessionToken)) {
                return new QueryResult(false, 'Session expired. Please verify your identity again');
            }
            
            RS_Bank_Account__c account = [
                SELECT Account_Number__c, Account_Type__c, Balance__c, 
                       Account_Status__c, Account_Holder__r.Name, Opening_Date__c
                FROM RS_Bank_Account__c 
                WHERE Account_Number__c = :accountNumber 
                LIMIT 1
            ];
            
            AccountSummary summary = new AccountSummary();
            summary.accountNumber = account.Account_Number__c;
            summary.accountType = account.Account_Type__c;
            summary.balance = account.Balance__c;
            summary.accountStatus = account.Account_Status__c;
            summary.holderName = account.Account_Holder__r.Name;
            summary.openingDate = account.Opening_Date__c;
            
            // Log access
            logDataAccess(account.Id, 'Balance_Check');
            
            QueryResult result = new QueryResult(true, 'Account balance retrieved successfully');
            result.data = summary;
            return result;
            
        } catch (Exception e) {
            return new QueryResult(false, 'Unable to retrieve account balance');
        }
    }
    
    // Get last N transactions
    @AuraEnabled
    public static QueryResult getRecentTransactions(String accountNumber, String sessionToken, Integer limitCount) {
        try {
            if (!BankingOTPService.isSessionValid(accountNumber, sessionToken)) {
                return new QueryResult(false, 'Session expired. Please verify your identity again');
            }
            
            if (limitCount == null || limitCount <= 0) limitCount = 5;
            if (limitCount > 20) limitCount = 20; // Security limit
            
            List<Transaction__c> transactions = [
                SELECT Transaction_ID__c, Transaction_Type__c, Amount__c, 
                       Transaction_Date__c, Description__c, Transaction_Status__c, 
                       Running_Balance__c
                FROM Transaction__c 
                WHERE Bank_Account__r.Account_Number__c = :accountNumber
                ORDER BY Transaction_Date__c DESC 
                LIMIT :limitCount
            ];
            
            List<TransactionRecord> records = new List<TransactionRecord>();
            for (Transaction__c txn : transactions) {
                TransactionRecord record = new TransactionRecord();
                record.transactionId = txn.Transaction_ID__c;
                record.type = txn.Transaction_Type__c;
                record.amount = txn.Amount__c;
                record.transactionDate = txn.Transaction_Date__c;
                record.description = txn.Description__c;
                record.status = txn.Transaction_Status__c;
                record.runningBalance = txn.Running_Balance__c;
                records.add(record);
            }
            
            // Log access
            RS_Bank_Account__c account = [SELECT Id FROM RS_Bank_Account__c WHERE Account_Number__c = :accountNumber LIMIT 1];
            logDataAccess(account.Id, 'Transaction_History');
            
            QueryResult result = new QueryResult(true, 'Retrieved ' + records.size() + ' recent transactions');
            result.data = records;
            return result;
            
        } catch (Exception e) {
            return new QueryResult(false, 'Unable to retrieve transaction history');
        }
    }
    
    // Get failed transactions
    @AuraEnabled
    public static QueryResult getFailedTransactions(String accountNumber, String sessionToken, Integer days) {
        try {
            if (!BankingOTPService.isSessionValid(accountNumber, sessionToken)) {
                return new QueryResult(false, 'Session expired. Please verify your identity again');
            }
            
            if (days == null || days <= 0) days = 30;
            if (days > 90) days = 90; // Limit to 90 days
            
            DateTime fromDate = DateTime.now().addDays(-days);
            
            List<Transaction__c> failedTxns = [
                SELECT Transaction_ID__c, Transaction_Type__c, Amount__c, 
                       Transaction_Date__c, Description__c, Transaction_Status__c
                FROM Transaction__c 
                WHERE Bank_Account__r.Account_Number__c = :accountNumber
                AND Transaction_Status__c IN ('Failed', 'Cancelled')
                AND Transaction_Date__c >= :fromDate
                ORDER BY Transaction_Date__c DESC
            ];
            
            List<TransactionRecord> records = new List<TransactionRecord>();
            for (Transaction__c txn : failedTxns) {
                TransactionRecord record = new TransactionRecord();
                record.transactionId = txn.Transaction_ID__c;
                record.type = txn.Transaction_Type__c;
                record.amount = txn.Amount__c;
                record.transactionDate = txn.Transaction_Date__c;
                record.description = txn.Description__c;
                record.status = txn.Transaction_Status__c;
                records.add(record);
            }
            
            // Log access
            RS_Bank_Account__c account = [SELECT Id FROM RS_Bank_Account__c WHERE Account_Number__c = :accountNumber LIMIT 1];
            logDataAccess(account.Id, 'Failed_Transactions');
            
            QueryResult result = new QueryResult(true, 'Found ' + records.size() + ' failed transactions in last ' + days + ' days');
            result.data = records;
            return result;
            
        } catch (Exception e) {
            return new QueryResult(false, 'Unable to retrieve failed transactions');
        }
    }
    
    // Get loan information
    @AuraEnabled
    public static QueryResult getLoanDetails(String accountNumber, String sessionToken) {
        try {
            if (!BankingOTPService.isSessionValid(accountNumber, sessionToken)) {
                return new QueryResult(false, 'Session expired. Please verify your identity again');
            }
            
            // Get account holder ID
            RS_Bank_Account__c account = [
                SELECT Account_Holder__c, Id
                FROM RS_Bank_Account__c 
                WHERE Account_Number__c = :accountNumber 
                LIMIT 1
            ];
            
            List<Loan__c> loans = [
                SELECT Loan_Number__c, Loan_Type__c, Principal_Amount__c, 
                       Interest_Rate__c, EMI_Amount__c, Outstanding_Amount__c, 
                       Loan_Status__c
                //Disbursement_Date__c, 
                //Maturity_Date__c
                FROM Loan__c 
                WHERE Account_Holder__c = :account.Account_Holder__c
                AND Loan_Status__c IN ('Active', 'Disbursed', 'Approved')
            ];
            
            logDataAccess(account.Id, 'Loan_Details');
            
            QueryResult result = new QueryResult(true, 'Retrieved ' + loans.size() + ' active loans');
            result.data = loans;
            return result;
            
        } catch (Exception e) {
            return new QueryResult(false, 'Unable to retrieve loan information');
        }
    }
    
    // Get card information
    @AuraEnabled
    public static QueryResult getCardDetails(String accountNumber, String sessionToken) {
        try {
            if (!BankingOTPService.isSessionValid(accountNumber, sessionToken)) {
                return new QueryResult(false, 'Session expired. Please verify your identity again');
            }
            
            List<Card__c> cards = [
                SELECT Card_Number__c, Card_Type__c, Card_Status__c, 
                       Issue_Date__c, Expiry_Date__c, Credit_Limit__c, Available_Limit__c
                FROM Card__c 
                WHERE Bank_Account__r.Account_Number__c = :accountNumber
            ];
            
            // Mask card numbers for security
            for (Card__c card : cards) {
                if (card.Card_Number__c != null && card.Card_Number__c.length() >= 4) {
                    String last4 = card.Card_Number__c.right(4);
                    card.Card_Number__c = '****-****-****-' + last4;
                }
            }
            
            // Log access
            RS_Bank_Account__c account = [SELECT Id FROM RS_Bank_Account__c WHERE Account_Number__c = :accountNumber LIMIT 1];
            logDataAccess(account.Id, 'Card_Details');
            
            QueryResult result = new QueryResult(true, 'Retrieved ' + cards.size() + ' cards');
            result.data = cards;
            return result;
            
        } catch (Exception e) {
            return new QueryResult(false, 'Unable to retrieve card information');
        }
    }
    
    private static void logDataAccess(String accountId, String dataType) {
        try {
            Security_Audit__c audit = new Security_Audit__c();
            audit.Bank_Account__c = accountId;
            audit.Event_Type__c = 'Data_Access';
            audit.Success__c = true;
            audit.Details__c = dataType;
            audit.Timestamp__c = DateTime.now();
            insert audit;
        } catch (Exception e) {
            System.debug('Audit logging error: ' + e.getMessage());
        }
    }
}