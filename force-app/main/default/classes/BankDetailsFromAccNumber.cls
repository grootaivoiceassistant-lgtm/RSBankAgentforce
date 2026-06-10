public class BankDetailsFromAccNumber {

    public class Request {
        @InvocableVariable(required=true)
        public String accountNumber;
        
        @InvocableVariable
        public String customerEmail;
        
        @InvocableVariable
        public String customerPhone;
    }

    public class Response {
       @InvocableVariable
        public String accountNumber;
        @InvocableVariable
        public String accountType;
        @InvocableVariable
        public Decimal balance;
        @InvocableVariable
        public String accountStatus;
        @InvocableVariable
        public String accountHolderName;
        @InvocableVariable
        public Date openingDate;
        @InvocableVariable
        public String customerEmail;
        @InvocableVariable
        public String customerPhone;
        @InvocableVariable
        public String nominee;
        @InvocableVariable
        public String panCardNumber;
        @InvocableVariable
        public String customerName;
        @InvocableVariable
        public String message;
    }

    @InvocableMethod(label='Get Bank Account Details' description='Fetch account details with optional verification')
    public static List<Response> getDetails(List<Request> requests) {
        List<Response> responses = new List<Response>();
        Set<String> accountNumbers = new Set<String>();
        for(Request req : requests) {
            if(String.isNotBlank(req.accountNumber)) accountNumbers.add(req.accountNumber);
        }

         // Query bank accounts and build a map with Account_Number__c as key
        Map<String, RS_Bank_Account__c> accountsMap = new Map<String, RS_Bank_Account__c>();
        for(RS_Bank_Account__c acc : [
            SELECT Account_Number__c,Name, Account_Type__c, Balance__c, Account_Status__c,
                  	Opening_Date__c,
                   Customer_Email__c, Customer_Phone__c, Nominee__c, PAN_Card_Number__c
            FROM RS_Bank_Account__c
            WHERE Account_Number__c IN :accountNumbers
        ]) {
            accountsMap.put(acc.Account_Number__c, acc);
        }

        for(Request req : requests) {
            Response res = new Response();
            RS_Bank_Account__c acc = accountsMap.get(req.accountNumber);
            if(acc != null) {
                res.accountNumber = acc.Account_Number__c;
                //res.accountHolderName = acc.Account_Holder__r.Name;

                // If email & phone NOT provided yet → return message only
                if(String.isBlank(req.customerEmail) || String.isBlank(req.customerPhone)) {
                    res.message = 'Please provide your registered email and phone for verification.';
                } else {
                    // Perform verification
                    if(acc.Customer_Email__c.equalsIgnoreCase(req.customerEmail)
                       && acc.Customer_Phone__c.equalsIgnoreCase(req.customerPhone)) {
                        res.accountNumber = acc.Account_Number__c;
                res.accountType = acc.Account_Type__c;
                res.balance = acc.Balance__c;
                res.accountStatus = acc.Account_Status__c;
                res.customerName = acc.Name;
                res.openingDate = acc.Opening_Date__c;
                res.customerEmail = acc.Customer_Email__c;
                res.customerPhone = acc.Customer_Phone__c;
                res.nominee = acc.Nominee__c;
                res.panCardNumber = acc.PAN_Card_Number__c;
                        res.message = 'Verification successful. Here are your account details.';
                    } else {
                        res.message = 'Verification failed: Email or Phone did not match.';
                    }
                }
            } else {
                res.message = 'No account found for the given account number.';
            }
            responses.add(res);
        }
        return responses;
    }
}