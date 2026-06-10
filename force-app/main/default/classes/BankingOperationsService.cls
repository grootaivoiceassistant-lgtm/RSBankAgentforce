public class BankingOperationsService {
    
    // Input wrapper for Flow
    public class BankingOperationRequest {
        @InvocableVariable(label='Operation Type' description='Type of operation: DEPOSIT, WITHDRAW, TRANSFER, LOAN_PAYMENT, CARD_PAYMENT, BALANCE_INQUIRY, TRANSACTION_HISTORY' required=true)
        public String operationType;
        
        @InvocableVariable(label='Account Number' description='Primary account number' required=true)
        public String accountNumber;
        
        @InvocableVariable(label='Amount' description='Transaction amount (required for financial operations)')
        public Decimal amount;
        
        @InvocableVariable(label='To Account Number' description='Target account number (required for TRANSFER)')
        public String toAccountNumber;
        
        @InvocableVariable(label='Description' description='Transaction description')
        public String description;
        
        @InvocableVariable(label='Payment Method' description='Payment method: Cash, ATM, Online, Mobile, etc.')
        public String paymentMethod;
        
        @InvocableVariable(label='Loan Number' description='Loan number (required for LOAN_PAYMENT)')
        public String loanNumber;
        
        @InvocableVariable(label='Card Number' description='Last 4 digits of card number (required for CARD_PAYMENT)')
        public String cardNumber;
        
        @InvocableVariable(label='Limit Count' description='Number of records to return (for TRANSACTION_HISTORY)')
        public Integer limitCount;
        
        @InvocableVariable(label='Transaction Type Filter' description='Filter transactions by type: Credit, Debit (for TRANSACTION_HISTORY)')
        public String transactionTypeFilter;
    }
    
    // Output wrapper for Flow
    public class BankingOperationResponse {
        @InvocableVariable(label='Success' description='True if operation was successful')
        public Boolean success;
        
        @InvocableVariable(label='Message' description='Result message')
        public String message;
        
        @InvocableVariable(label='Transaction ID' description='Generated transaction ID')
        public String transactionId;
        
        @InvocableVariable(label='New Balance' description='Updated account balance')
        public Decimal newBalance;
        
        @InvocableVariable(label='Account Balance' description='Current account balance (for BALANCE_INQUIRY)')
        public Decimal accountBalance;
        
        @InvocableVariable(label='Account Type' description='Type of account')
        public String accountType;
        
        @InvocableVariable(label='Account Status' description='Status of account')
        public String accountStatus;
        
        @InvocableVariable(label='Transaction Records' description='List of transactions (for TRANSACTION_HISTORY)')
        public String transactionRecords; // JSON string of transactions
        
        @InvocableVariable(label='Error Details' description='Detailed error information')
        public String errorDetails;
    }
    
    // Main invocable method for Flow
    @InvocableMethod(label='Banking Operations' description='Perform various banking operations: Deposit, Withdraw, Transfer, Loan Payment, Card Payment, Balance Inquiry, Transaction History')
    public static List<BankingOperationResponse> performBankingOperation(List<BankingOperationRequest> requests) {
        System.debug('inside performBankingOperation');
        List<BankingOperationResponse> responses = new List<BankingOperationResponse>();
        
        for (BankingOperationRequest request : requests) {
            BankingOperationResponse response = new BankingOperationResponse();
            
            try {
                switch on request.operationType.toUpperCase() {
                    when 'DEPOSIT' {
                        response = processDeposit(request);
                    }
                    when 'WITHDRAW' {
                        response = processWithdrawal(request);
                    }
                    when 'TRANSFER' {
                        response = processTransfer(request);
                    }
                    when 'LOAN_PAYMENT' {
                        response = processLoanPayment(request);
                    }
                    when 'CARD_PAYMENT' {
                        response = processCardPayment(request);
                    }
                    when 'BALANCE_INQUIRY' {
                        response = processBalanceInquiry(request);
                    }
                    when 'TRANSACTION_HISTORY' {
                        System.debug('line 96');
                        response = processTransactionHistory(request);
                    }
                    when else {
                        response.success = false;
                        response.message = 'Invalid operation type. Valid types: DEPOSIT, WITHDRAW, TRANSFER, LOAN_PAYMENT, CARD_PAYMENT, BALANCE_INQUIRY, TRANSACTION_HISTORY';
                    }
                }
            } catch (Exception e) {
                response.success = false;
                response.message = 'System error occurred';
                response.errorDetails = e.getMessage();
                System.debug('Banking Operation Error: ' + e.getMessage());
                System.debug('Stack Trace: ' + e.getStackTraceString());
            }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    // DEPOSIT Operation
    private static BankingOperationResponse processDeposit(BankingOperationRequest request) {
        BankingOperationResponse response = new BankingOperationResponse();
        
        // Validate inputs
        if (request.amount == null || request.amount <= 0) {
            response.success = false;
            response.message = 'Deposit amount must be greater than zero';
            return response;
        }
        
        if (request.amount > 1000000) {
            response.success = false;
            response.message = 'Deposit amount exceeds maximum limit of 1,000,000';
            return response;
        }
        
        try {
            // Get account
            RS_Bank_Account__c account = getBankAccount(request.accountNumber);
            if (account.Account_Status__c != 'Active') {
                response.success = false;
                response.message = 'Account is not active for transactions';
                return response;
            }
            
            // Process deposit transaction
            Decimal newBalance = account.Balance__c + request.amount;
            
            // Create transaction record
            Transaction__c transactions = new Transaction__c();
            transactions.Name = 'DEP-' + generateTransactionNumber();
            transactions.Bank_Account__c = account.Id;
            transactions.Transaction_Type__c = 'Credit';
            transactions.Amount__c = request.amount;
            transactions.Description__c = (String.isBlank(request.description) ? 'Cash Deposit' : request.description) + 
                                       (String.isNotBlank(request.paymentMethod) ? ' via ' + request.paymentMethod : '');
            transactions.Transaction_Date__c = System.now();
            transactions.Transaction_Status__c = 'Completed';
            transactions.Running_Balance__c = newBalance;
            transactions.Transaction_ID__c = generateTransactionId();
            
            // Update account balance
            account.Balance__c = newBalance;
            account.Last_Transaction_Date__c = System.now();
            
            // Perform database operations
            insert transactions;
            update account;
            
            // Log security audit
            logSecurityAudit(account.Id, 'DEPOSIT', true, 'Deposit of ' + request.amount + ' completed successfully');
            
            response.success = true;
            response.message = 'Deposit successful';
            response.transactionId = transactions.Transaction_ID__c;
            response.newBalance = newBalance;
            response.accountType = account.Account_Type__c;
            response.accountStatus = account.Account_Status__c;
            
        } catch (Exception e) {
            response.success = false;
            response.message = 'Deposit failed';
            response.errorDetails = e.getMessage();
            logSecurityAudit(null, 'DEPOSIT', false, 'Deposit failed: ' + e.getMessage());
        }
        
        return response;
    }
    
    // WITHDRAWAL Operation
    private static BankingOperationResponse processWithdrawal(BankingOperationRequest request) {
        BankingOperationResponse response = new BankingOperationResponse();
        
        // Validate inputs
        if (request.amount == null || request.amount <= 0) {
            response.success = false;
            response.message = 'Withdrawal amount must be greater than zero';
            return response;
        }
        
        try {
            // Get account
            RS_Bank_Account__c account = getBankAccount(request.accountNumber);
            if (account.Account_Status__c != 'Active') {
                response.success = false;
                response.message = 'Account is not active for transactions';
                return response;
            }
            
            // Check sufficient balance
            if (account.Balance__c < request.amount) {
                response.success = false;
                response.message = 'Insufficient balance. Available: ' + account.Balance__c;
                logSecurityAudit(account.Id, 'WITHDRAWAL', false, 'Insufficient funds for withdrawal of ' + request.amount);
                return response;
            }
            
            // Check daily withdrawal limit
            Decimal dailyLimit = getDailyWithdrawalLimit(account.Account_Type__c);
            Decimal todayWithdraws = getTodayWithdrawals(account.Id);
            
            if (todayWithdraws + request.amount > dailyLimit) {
                response.success = false;
                response.message = 'Daily withdrawal limit exceeded. Limit: ' + dailyLimit + ', Already withdrawn today: ' + todayWithdraws;
                return response;
            }
            
            // Process withdrawal transaction
            Decimal newBalance = account.Balance__c - request.amount;
            
            // Create transaction record
            Transaction__c transactions = new Transaction__c();
            transactions.Name = 'WTH-' + generateTransactionNumber();
            transactions.Bank_Account__c = account.Id;
            transactions.Transaction_Type__c = 'Debit';
            transactions.Amount__c = request.amount;
            transactions.Description__c = (String.isBlank(request.description) ? 'Cash Withdrawal' : request.description) + 
                                       (String.isNotBlank(request.paymentMethod) ? ' via ' + request.paymentMethod : '');
            transactions.Transaction_Date__c = System.now();
            transactions.Transaction_Status__c = 'Completed';
            transactions.Running_Balance__c = newBalance;
            transactions.Transaction_ID__c = generateTransactionId();
            
            // Update account balance
            account.Balance__c = newBalance;
            account.Last_Transaction_Date__c = System.now();
            
            // Perform database operations
            insert transactions;
            update account;
            
            // Log security audit
            logSecurityAudit(account.Id, 'WITHDRAWAL', true, 'Withdrawal of ' + request.amount + ' completed successfully');
            
            response.success = true;
            response.message = 'Withdrawal successful';
            response.transactionId = transactions.Transaction_ID__c;
            response.newBalance = newBalance;
            response.accountType = account.Account_Type__c;
            response.accountStatus = account.Account_Status__c;
            
        } catch (Exception e) {
            response.success = false;
            response.message = 'Withdrawal failed';
            response.errorDetails = e.getMessage();
            logSecurityAudit(null, 'WITHDRAWAL', false, 'Withdrawal failed: ' + e.getMessage());
        }
        
        return response;
    }
    
    // TRANSFER Operation
    private static BankingOperationResponse processTransfer(BankingOperationRequest request) {
        System.debug('inside processTransfer');
        System.debug('request--'+request);
        BankingOperationResponse response = new BankingOperationResponse();
        
        // Validate inputs
        if (request.amount == null || request.amount <= 0) {
            response.success = false;
            response.message = 'Transfer amount must be greater than zero';
            return response;
        }
        
        if (String.isBlank(request.toAccountNumber)) {
            response.success = false;
            response.message = 'To Account Number is required for transfer';
            return response;
        }
        
        if (request.accountNumber.equals(request.toAccountNumber)) {
            response.success = false;
            response.message = 'Cannot transfer to same account';
            return response;
        }
        
        try {
            // Get both accounts
            RS_Bank_Account__c sourceAccount = getBankAccount(request.accountNumber);
            RS_Bank_Account__c targetAccount = getBankAccount(request.toAccountNumber);
            System.debug('sourceAccount--'+sourceAccount);
            System.debug('targetAccount--'+targetAccount);
            System.debug('line 300');
            // Validate accounts
            if (sourceAccount.Account_Status__c != 'Active' || targetAccount.Account_Status__c != 'Active') {
                System.debug('line 303');
                response.success = false;
                response.message = 'One or both accounts are not active';
                return response;
            }
            System.debug('line 308');
            // Check sufficient balance
            if (sourceAccount.Balance__c < request.amount) {
                System.debug('line 311');
                response.success = false;
                response.message = 'Insufficient balance in source account';
                return response;
            }
            System.debug('line 316');
            // Check transfer limits
            Decimal dailyTransferLimit = getDailyTransferLimit(sourceAccount.Account_Type__c);
            Decimal todayTransfers = getTodayTransfers(sourceAccount.Id);
            System.debug('dailyTransferLimit--'+dailyTransferLimit);
            System.debug('todayTransfers--'+todayTransfers);
            
            
            if (todayTransfers + request.amount > dailyTransferLimit) {
                System.debug('line 323');
                response.success = false;
                response.message = 'Daily transfer limit exceeded';
                return response;
            }
            System.debug('line 330');
            // Process transfer
            System.debug('sourceAccount.Balance__c--'+sourceAccount.Balance__c);
            System.debug('targetAccount.Balance__c--'+targetAccount.Balance__c);
            System.debug('request.amount--'+request.amount);
            Decimal sourceNewBalance = sourceAccount.Balance__c - request.amount;
            Decimal targetNewBalance = targetAccount.Balance__c + request.amount;
            System.debug('sourceNewBalance--'+sourceNewBalance);
            System.debug('targetNewBalance--'+targetNewBalance);
            
            String transferReference = generateTransactionId();
            
            // Create debit transaction
            Transaction__c debitTransaction = new Transaction__c();
            debitTransaction.Name = 'TRF-' + generateTransactionNumber();
            debitTransaction.Bank_Account__c = sourceAccount.Id;
            debitTransaction.Transaction_Type__c = 'Debit';
            debitTransaction.Amount__c = request.amount;
            debitTransaction.Description__c = 'Transfer to ' + request.toAccountNumber + (String.isNotBlank(request.description) ? ' - ' + request.description : '');
            debitTransaction.Transaction_Date__c = System.now();
            debitTransaction.Transaction_Status__c = 'Completed';
            debitTransaction.Running_Balance__c = sourceNewBalance;
            debitTransaction.Transaction_ID__c = transferReference;
            
            // Create credit transaction
            Transaction__c creditTransaction = new Transaction__c();
            creditTransaction.Name = 'TRF-' + generateTransactionNumber();
            creditTransaction.Bank_Account__c = targetAccount.Id;
            creditTransaction.Transaction_Type__c = 'Credit';
            creditTransaction.Amount__c = request.amount;
            creditTransaction.Description__c = 'Transfer from ' + request.accountNumber + (String.isNotBlank(request.description) ? ' - ' + request.description : '');
            creditTransaction.Transaction_Date__c = System.now();
            creditTransaction.Transaction_Status__c = 'Completed';
            creditTransaction.Running_Balance__c = targetNewBalance;
            creditTransaction.Transaction_ID__c = transferReference;
            
            // Update account balances
            sourceAccount.Balance__c = sourceNewBalance;
            sourceAccount.Last_Transaction_Date__c = System.now();
            targetAccount.Balance__c = targetNewBalance;
            targetAccount.Last_Transaction_Date__c = System.now();
            
            // Perform database operations
            insert new List<Transaction__c>{debitTransaction, creditTransaction};
            update new List<RS_Bank_Account__c>{sourceAccount, targetAccount};
            
            // Log security audit
            logSecurityAudit(sourceAccount.Id, 'TRANSFER_OUT', true, 'Transfer of ' + request.amount + ' to ' + request.toAccountNumber);
            logSecurityAudit(targetAccount.Id, 'TRANSFER_IN', true, 'Transfer of ' + request.amount + ' from ' + request.accountNumber);
            
            response.success = true;
            response.message = 'Transfer successful';
            response.transactionId = transferReference;
            response.newBalance = sourceNewBalance;
            response.accountType = sourceAccount.Account_Type__c;
            response.accountStatus = sourceAccount.Account_Status__c;
            
        } catch (Exception e) {
            response.success = false;
            response.message = 'Transfer failed';
            response.errorDetails = e.getMessage();
            logSecurityAudit(null, 'TRANSFER', false, 'Transfer failed: ' + e.getMessage());
        }
        
        return response;
    }
    
    // LOAN PAYMENT Operation
    private static BankingOperationResponse processLoanPayment(BankingOperationRequest request) {
        BankingOperationResponse response = new BankingOperationResponse();
        
        if (String.isBlank(request.loanNumber)) {
            response.success = false;
            response.message = 'Loan Number is required for loan payment';
            return response;
        }
        
        if (request.amount == null || request.amount <= 0) {
            response.success = false;
            response.message = 'Payment amount must be greater than zero';
            return response;
        }
        
        try {
            // Get account and loan
            RS_Bank_Account__c account = getBankAccount(request.accountNumber);
            
            List<Loan__c> loans = [
                SELECT Id, Outstanding_Amount__c, EMI_Amount__c, Loan_Status__c
                FROM Loan__c 
                WHERE Loan_Number__c = :request.loanNumber 
                AND Account_Holder__c = :account.Account_Holder__c
                AND Loan_Status__c = 'Active'
                LIMIT 1
            ];
            
            if (loans.isEmpty()) {
                response.success = false;
                response.message = 'Active loan not found';
                return response;
            }
            
            Loan__c loan = loans[0];
            
            // Check sufficient balance
            if (account.Balance__c < request.amount) {
                response.success = false;
                response.message = 'Insufficient balance for loan payment';
                return response;
            }
            
            // Process loan payment
            Decimal newBalance = account.Balance__c - request.amount;
            Decimal newOutstanding = loan.Outstanding_Amount__c - request.amount;
            
            // Create transaction
            Transaction__c transactions = new Transaction__c();
            transactions.Name = 'LOAN-' + generateTransactionNumber();
            transactions.Bank_Account__c = account.Id;
            transactions.Transaction_Type__c = 'Debit';
            transactions.Amount__c = request.amount;
            transactions.Description__c = 'Loan EMI Payment - ' + request.loanNumber;
            transactions.Transaction_Date__c = System.now();
            transactions.Transaction_Status__c = 'Completed';
            transactions.Running_Balance__c = newBalance;
            transactions.Transaction_ID__c = generateTransactionId();
            
            // Update records
            account.Balance__c = newBalance;
            account.Last_Transaction_Date__c = System.now();
            loan.Outstanding_Amount__c = Math.max(newOutstanding, 0);
            
            if (newOutstanding <= 0) {
                loan.Loan_Status__c = 'Closed';
            }
            
            insert transactions;
            update new List<SObject>{account, loan};
            
            logSecurityAudit(account.Id, 'LOAN_PAYMENT', true, 'Loan payment of ' + request.amount);
            
            response.success = true;
            response.message = 'Loan payment successful' + (newOutstanding <= 0 ? '. Loan is now closed.' : '');
            response.transactionId = transactions.Transaction_ID__c;
            response.newBalance = newBalance;
            response.accountType = account.Account_Type__c;
            response.accountStatus = account.Account_Status__c;
            
        } catch (Exception e) {
            response.success = false;
            response.message = 'Loan payment failed';
            response.errorDetails = e.getMessage();
        }
        
        return response;
    }
    
    // CARD PAYMENT Operation
    private static BankingOperationResponse processCardPayment(BankingOperationRequest request) {
        BankingOperationResponse response = new BankingOperationResponse();
        
        if (String.isBlank(request.cardNumber)) {
            response.success = false;
            response.message = 'Card Number (last 4 digits) is required for card payment';
            return response;
        }
        
        if (request.amount == null || request.amount <= 0) {
            response.success = false;
            response.message = 'Payment amount must be greater than zero';
            return response;
        }
        
        try {
            // Get account and card
            RS_Bank_Account__c account = getBankAccount(request.accountNumber);
            
            List<Card__c> cards = [
                SELECT Id, Outstanding_Amount__c, Available_Limit__c, Credit_Limit__c
                FROM Card__c 
                WHERE 
                //Card_Number__c LIKE :('%' + request.cardNumber)
                //AND 
                Bank_Account__c = :account.Id
                AND Card_Status__c = 'Active'
                LIMIT 1
            ];
            
            if (cards.isEmpty()) {
                response.success = false;
                response.message = 'Active card not found';
                return response;
            }
            
            Card__c card = cards[0];
            
            // Check sufficient balance
            if (account.Balance__c < request.amount) {
                response.success = false;
                response.message = 'Insufficient balance for card payment';
                return response;
            }
            
            // Process card payment
            Decimal newBalance = account.Balance__c - request.amount;
            Decimal newOutstanding = Math.max(card.Outstanding_Amount__c - request.amount, 0);
            Decimal newAvailable = Math.min(card.Available_Limit__c + request.amount, card.Credit_Limit__c);
            
            // Create transaction
            Transaction__c transactions = new Transaction__c();
            transactions.Name = 'CARD-' + generateTransactionNumber();
            transactions.Bank_Account__c = account.Id;
            transactions.Transaction_Type__c = 'Debit';
            transactions.Amount__c = request.amount;
            transactions.Description__c = 'Credit Card Payment - ****' + request.cardNumber;
            transactions.Transaction_Date__c = System.now();
            transactions.Transaction_Status__c = 'Completed';
            transactions.Running_Balance__c = newBalance;
            transactions.Transaction_ID__c = generateTransactionId();
            
            // Update records
            account.Balance__c = newBalance;
            account.Last_Transaction_Date__c = System.now();
            card.Outstanding_Amount__c = newOutstanding;
            card.Available_Limit__c = newAvailable;
            
            insert transactions;
            update new List<SObject>{account, card};
            
            logSecurityAudit(account.Id, 'CARD_PAYMENT', true, 'Card payment of ' + request.amount);
            
            response.success = true;
            response.message = 'Card payment successful';
            response.transactionId = transactions.Transaction_ID__c;
            response.newBalance = newBalance;
            response.accountType = account.Account_Type__c;
            response.accountStatus = account.Account_Status__c;
            
        } catch (Exception e) {
            response.success = false;
            response.message = 'Card payment failed';
            response.errorDetails = e.getMessage();
        }
        
        return response;
    }
    
    // BALANCE INQUIRY Operation
    private static BankingOperationResponse processBalanceInquiry(BankingOperationRequest request) {
        BankingOperationResponse response = new BankingOperationResponse();
        
        try {
            RS_Bank_Account__c account = getBankAccount(request.accountNumber);
            
            logSecurityAudit(account.Id, 'BALANCE_INQUIRY', true, 'Balance inquiry performed');
            
            response.success = true;
            response.message = 'Balance retrieved successfully';
            response.accountBalance = account.Balance__c;
            response.newBalance = account.Balance__c;
            response.accountType = account.Account_Type__c;
            response.accountStatus = account.Account_Status__c;
            
        } catch (Exception e) {
            response.success = false;
            response.message = 'Balance inquiry failed';
            response.errorDetails = e.getMessage();
        }
        
        return response;
    }
    
    // TRANSACTION HISTORY Operation
    private static BankingOperationResponse processTransactionHistory(BankingOperationRequest request) {
        System.debug('inside processTransactionHistory');
        BankingOperationResponse response = new BankingOperationResponse();
        
        try {
            RS_Bank_Account__c account = getBankAccount(request.accountNumber);
            System.debug('account--'+account);
            
            Integer limitCount = request.limitCount != null && request.limitCount > 0 ? request.limitCount : 10;
            System.debug('limitCount--'+limitCount);
            if (limitCount > 50) limitCount = 50; // Security limit
            System.debug('account.id--'+account.Id);
            String query =
    'SELECT Transaction_ID__c, Transaction_Type__c, Amount__c, ' +
    'Transaction_Date__c, Description__c, Running_Balance__c, Transaction_Status__c ' +
    'FROM Transaction__c WHERE Bank_Account__c = \'' + account.Id + '\'';

            System.debug('request.transactionTypeFilter--'+request.transactionTypeFilter);
            if (String.isNotBlank(request.transactionTypeFilter)) {
                query += 'AND Transaction_Type__c = :request.transactionTypeFilter ';
            }
            
            query += 'ORDER BY Transaction_Date__c DESC LIMIT :limitCount';
            System.debug('query--'+query);
            
            List<Transaction__c> transactions = Database.query(query);
            System.debug('transactions--'+transactions);
            
            // Convert to JSON for Flow consumption
            List<Map<String, Object>> transactionMaps = new List<Map<String, Object>>();
            for (Transaction__c txn : transactions) {
                Map<String, Object> txnMap = new Map<String, Object>();
                txnMap.put('transactionId', txn.Transaction_ID__c);
                txnMap.put('type', txn.Transaction_Type__c);
                txnMap.put('amount', txn.Amount__c);
                txnMap.put('date', txn.Transaction_Date__c);
                txnMap.put('description', txn.Description__c);
                txnMap.put('balance', txn.Running_Balance__c);
                txnMap.put('status', txn.Transaction_Status__c);
                transactionMaps.add(txnMap);
            }
            
            logSecurityAudit(account.Id, 'TRANSACTION_HISTORY', true, 'Transaction history accessed');
            
            response.success = true;
            response.message = 'Retrieved ' + transactions.size() + ' transactions';
            response.transactionRecords = JSON.serialize(transactionMaps);
            response.accountBalance = account.Balance__c;
            response.accountType = account.Account_Type__c;
            response.accountStatus = account.Account_Status__c;
            
        } catch (Exception e) {
            response.success = false;
            response.message = 'Transaction history failed';
            response.errorDetails = e.getMessage();
        }
        
        return response;
    }
    
    // UTILITY METHODS
    private static RS_Bank_Account__c getBankAccount(String accountNumber) {
        List<RS_Bank_Account__c> accounts = [
            SELECT Id, Account_Number__c, Balance__c, Account_Status__c, 
                   Account_Type__c, Account_Holder__c, Last_Transaction_Date__c
            FROM RS_Bank_Account__c 
            WHERE Account_Number__c = :accountNumber 
            LIMIT 1
        ];
        
        if (accounts.isEmpty()) {
            throw new AuraHandledException('Account not found: ' + accountNumber);
        }
        
        return accounts[0];
    }
    
    private static String generateTransactionId() {
        return 'TXN' + String.valueOf(System.now().getTime()).right(10) + 
               String.valueOf(Math.random()).substring(2, 6);
    }
    
    private static String generateTransactionNumber() {
        return String.valueOf(System.now().getTime()).right(8);
    }
    
    private static Decimal getDailyWithdrawalLimit(String accountType) {
        Map<String, Decimal> limits = new Map<String, Decimal>{
            'Savings' => 50000,
            'Current' => 200000,
            'Salary' => 100000
        };
        return limits.get(accountType) != null ? limits.get(accountType) : 50000;
    }
    
    private static Decimal getDailyTransferLimit(String accountType) {
        Map<String, Decimal> limits = new Map<String, Decimal>{
            'Savings' => 100000,
            'Current' => 500000,
            'Salary' => 200000
        };
        return limits.get(accountType) != null ? limits.get(accountType) : 100000;
    }
    
    private static Decimal getTodayWithdrawals(Id accountId) {
        Date today = Date.today();
        DateTime startOfDay = DateTime.newInstance(today, Time.newInstance(0, 0, 0, 0));
        DateTime endOfDay = DateTime.newInstance(today, Time.newInstance(23, 59, 59, 999));
        
        List<AggregateResult> results = [
            SELECT SUM(Amount__c) total
            FROM Transaction__c 
            WHERE Bank_Account__c = :accountId 
            AND Transaction_Type__c = 'Debit'
            AND Transaction_Date__c >= :startOfDay 
            AND Transaction_Date__c <= :endOfDay
            AND Transaction_Status__c = 'Completed'
        ];
        
        return (Decimal)results[0].get('total') != null ? (Decimal)results[0].get('total') : 0;
    }
    
    private static Decimal getTodayTransfers(Id accountId) {
        Date today = Date.today();
        DateTime startOfDay = DateTime.newInstance(today, Time.newInstance(0, 0, 0, 0));
        DateTime endOfDay = DateTime.newInstance(today, Time.newInstance(23, 59, 59, 999));
        
        List<AggregateResult> results = [
            SELECT SUM(Amount__c) total
            FROM Transaction__c 
            WHERE Bank_Account__c = :accountId 
            AND Transaction_Type__c = 'Debit'
            AND Description__c LIKE 'Transfer to%'
            AND Transaction_Date__c >= :startOfDay 
            AND Transaction_Date__c <= :endOfDay
            AND Transaction_Status__c = 'Completed'
        ];
        
        return (Decimal)results[0].get('total') != null ? (Decimal)results[0].get('total') : 0;
    }
    
    private static void logSecurityAudit(Id accountId, String eventType, Boolean success, String details) {
        try {
            Security_Audit__c audit = new Security_Audit__c();
            audit.Bank_Account__c = accountId;
            audit.Event_Type__c = eventType;
            audit.Success__c = success;
            audit.Details__c = details;
            audit.Timestamp__c = System.now();
            insert audit;
        } catch (Exception e) {
            System.debug('Audit logging error: ' + e.getMessage());
        }
    }
}