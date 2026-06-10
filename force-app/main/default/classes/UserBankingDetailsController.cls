public with sharing class UserBankingDetailsController {
    
    public class BankAccountDetails {
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String accountType;
        @AuraEnabled public Decimal balance;
        @AuraEnabled public String status;
        @AuraEnabled public Date openingDate;
        @AuraEnabled public String nominee;
        @AuraEnabled public String panCard;
        // Add other RS_Bank_Account__c fields as needed
    }
    
    public class TransactionDetails {
        @AuraEnabled public String transactionId;
        @AuraEnabled public String type;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public DateTime transactionDate;
        @AuraEnabled public String description;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal runningBalance;
        // Add other Transaction__c fields as needed
    }
    
    public class LoanDetails {
        @AuraEnabled public String loanNumber;
        @AuraEnabled public String loanType;
        @AuraEnabled public Decimal principalAmount;
        @AuraEnabled public Decimal interestRate;
        @AuraEnabled public Decimal emiAmount;
        @AuraEnabled public Decimal outstandingAmount;
        @AuraEnabled public String loanStatus;
        // Add other Loan__c fields as needed
    }
    
    public class CardDetails {
        @AuraEnabled public String cardNumber;
        @AuraEnabled public String cardType;
        @AuraEnabled public String cardStatus;
        @AuraEnabled public Date issueDate;
        @AuraEnabled public Date expiryDate;
        @AuraEnabled public Decimal creditLimit;
        @AuraEnabled public Decimal availableLimit;
        // Add other Card__c fields as needed
    }
    
    public class UserBankingDetails {
        @AuraEnabled public List<BankAccountDetails> bankAccounts;
        @AuraEnabled public List<TransactionDetails> transactions;
        @AuraEnabled public List<LoanDetails> loans;
        @AuraEnabled public List<CardDetails> cards;
    }
    
    @AuraEnabled(cacheable=true)
    public static UserBankingDetails getUserBankingDetails(Id userId) {
        try {
            // Get user email
            User currentUser = [SELECT Email FROM User WHERE Id = :userId LIMIT 1];
            String userEmail = currentUser.Email;
            
            // Fetch bank accounts
            List<RS_Bank_Account__c> accounts = [
                SELECT Id, Account_Number__c, Account_Type__c, Balance__c, Account_Status__c, 
                       Opening_Date__c, Nominee__c, PAN_Card_Number__c
                FROM RS_Bank_Account__c
                WHERE Customer_Email__c = :userEmail
            ];
            
            List<BankAccountDetails> bankDetails = new List<BankAccountDetails>();
            Set<Id> accountIds = new Set<Id>();
            for (RS_Bank_Account__c acc : accounts) {
                BankAccountDetails bd = new BankAccountDetails();
                bd.accountNumber = acc.Account_Number__c;
                bd.accountType = acc.Account_Type__c;
                bd.balance = acc.Balance__c;
                bd.status = acc.Account_Status__c;
                bd.openingDate = acc.Opening_Date__c;
                bd.nominee = acc.Nominee__c;
                bd.panCard = acc.PAN_Card_Number__c;
                bankDetails.add(bd);
                accountIds.add(acc.Id);
            }
            
            // Fetch transactions
            List<Transaction__c> txns = [
                SELECT Transaction_ID__c, Transaction_Type__c, Amount__c, Transaction_Date__c, 
                       Description__c, Transaction_Status__c, Running_Balance__c
                FROM Transaction__c
                WHERE Bank_Account__c IN :accountIds
                ORDER BY Transaction_Date__c DESC
            ];
            
            List<TransactionDetails> txnDetails = new List<TransactionDetails>();
            for (Transaction__c txn : txns) {
                TransactionDetails td = new TransactionDetails();
                td.transactionId = txn.Transaction_ID__c;
                td.type = txn.Transaction_Type__c;
                td.amount = txn.Amount__c;
                td.transactionDate = txn.Transaction_Date__c;
                td.description = txn.Description__c;
                td.status = txn.Transaction_Status__c;
                td.runningBalance = txn.Running_Balance__c;
                txnDetails.add(td);
            }
            
            // Fetch loans
            List<Loan__c> loans = [
                SELECT Loan_Number__c, Loan_Type__c, Principal_Amount__c, Interest_Rate__c,
                       EMI_Amount__c, Outstanding_Amount__c, Loan_Status__c
                FROM Loan__c
                WHERE RS_Bank_Account__r.Customer_Email__c = :userEmail
            ];
            
            List<LoanDetails> loanDetails = new List<LoanDetails>();
            for (Loan__c loan : loans) {
                LoanDetails ld = new LoanDetails();
                ld.loanNumber = loan.Loan_Number__c;
                ld.loanType = loan.Loan_Type__c;
                ld.principalAmount = loan.Principal_Amount__c;
                ld.interestRate = loan.Interest_Rate__c;
                ld.emiAmount = loan.EMI_Amount__c;
                ld.outstandingAmount = loan.Outstanding_Amount__c;
                ld.loanStatus = loan.Loan_Status__c;
                loanDetails.add(ld);
            }
            
            // Fetch cards
            List<Card__c> cards = [
                SELECT Card_Number__c, Card_Type__c, Card_Status__c, Issue_Date__c,
                       Expiry_Date__c, Credit_Limit__c, Available_Limit__c
                FROM Card__c
                WHERE Bank_Account__r.Customer_Email__c = :userEmail
            ];
            
            List<CardDetails> cardDetails = new List<CardDetails>();
            for (Card__c card : cards) {
                CardDetails cd = new CardDetails();
                cd.cardNumber = card.Card_Number__c;
                cd.cardType = card.Card_Type__c;
                cd.cardStatus = card.Card_Status__c;
                cd.issueDate = card.Issue_Date__c;
                cd.expiryDate = card.Expiry_Date__c;
                cd.creditLimit = card.Credit_Limit__c;
                cd.availableLimit = card.Available_Limit__c;
                cardDetails.add(cd);
            }
            
            UserBankingDetails result = new UserBankingDetails();
            result.bankAccounts = bankDetails;
            result.transactions = txnDetails;
            result.loans = loanDetails;
            result.cards = cardDetails;
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching user banking details: ' + e.getMessage());
        }
    }
}