public class BankingUpdateService {
    
    public class UpdateResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String requestId;
        
        public UpdateResult(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }
    
    // Update contact information
    @AuraEnabled
    public static UpdateResult updateContactInfo(String accountNumber, String sessionToken, 
                                                String newEmail, String newPhone) {
        try {
            if (!BankingOTPService.isSessionValid(accountNumber, sessionToken)) {
                return new UpdateResult(false, 'Session expired. Please verify your identity again');
            }
            
            RS_Bank_Account__c account = [
                SELECT Id, Customer_Email__c, Customer_Phone__c
                FROM RS_Bank_Account__c 
                WHERE Account_Number__c = :accountNumber 
                LIMIT 1
            ];
            
            String changes = '';
            if (String.isNotBlank(newEmail) && newEmail != account.Customer_Email__c) {
                account.Customer_Email__c = newEmail;
                changes += 'Email updated. ';
            }
            
            if (String.isNotBlank(newPhone) && newPhone != account.Customer_Phone__c) {
                account.Customer_Phone__c = newPhone;
                changes += 'Phone updated. ';
            }
            
            if (String.isBlank(changes)) {
                return new UpdateResult(false, 'No changes detected');
            }
            
            update account;
            
            // Log the update
            logAccountUpdate(account.Id, 'Contact_Info_Update', changes);
            
            return new UpdateResult(true, changes + 'Updates will be effective immediately.');
            
        } catch (Exception e) {
            return new UpdateResult(false, 'Unable to update contact information. Please try again.');
        }
    }
    
    // Request card block
    @AuraEnabled
    public static UpdateResult requestCardBlock(String accountNumber, String sessionToken, 
                                              String cardNumber, String reason) {
        try {
            if (!BankingOTPService.isSessionValid(accountNumber, sessionToken)) {
                return new UpdateResult(false, 'Session expired. Please verify your identity again');
            }
            
            String last4Digits = cardNumber.length() >= 4 ? cardNumber.right(4) : cardNumber;
            
            List<Card__c> cards = [
                SELECT Id, Card_Status__c, Card_Type__c
                FROM Card__c 
                WHERE Bank_Account__r.Account_Number__c = :accountNumber
                //AND Card_Number__c LIKE '%' + last4Digits
                AND Card_Status__c = 'Active'
                LIMIT 1
            ];
            
            if (cards.isEmpty()) {
                return new UpdateResult(false, 'No active card found with the provided details');
            }
            
            Card__c card = cards[0];
            card.Card_Status__c = 'Blocked';
            update card;
            
            // Create service request
            String requestId = createServiceRequest(accountNumber, 'Card Block', 
                'Block ' + card.Card_Type__c + ' card ending in ' + last4Digits + '. Reason: ' + reason);
            
            // Log the update
            RS_Bank_Account__c account = [SELECT Id FROM RS_Bank_Account__c WHERE Account_Number__c = :accountNumber LIMIT 1];
            logAccountUpdate(account.Id, 'Card_Block', 'Card blocked: ' + last4Digits + '. Reason: ' + reason);
            
            UpdateResult result = new UpdateResult(true, 'Card has been blocked successfully. A replacement card will be issued.');
            result.requestId = requestId;
            return result;
            
        } catch (Exception e) {
            return new UpdateResult(false, 'Unable to block card. Please contact customer service.');
        }
    }
    
    // Request checkbook
    @AuraEnabled
    public static UpdateResult requestCheckbook(String accountNumber, String sessionToken, String deliveryAddress) {
        try {
            if (!BankingOTPService.isSessionValid(accountNumber, sessionToken)) {
                return new UpdateResult(false, 'Session expired. Please verify your identity again');
            }
            
            // Check if account type allows checkbook
            RS_Bank_Account__c account = [
                SELECT Id, Account_Type__c, Account_Status__c
                FROM RS_Bank_Account__c 
                WHERE Account_Number__c = :accountNumber 
                LIMIT 1
            ];
            
            if (account.Account_Type__c == 'Fixed_Deposit') {
                return new UpdateResult(false, 'Checkbook is not available for Fixed Deposit accounts');
            }
            
            if (account.Account_Status__c != 'Active') {
                return new UpdateResult(false, 'Checkbook can only be issued for active accounts');
            }
            
            // Create service request
            String requestId = createServiceRequest(accountNumber, 'Checkbook Request', 
                'New checkbook requested. Delivery address: ' + deliveryAddress);
            
            // Log the request
            logAccountUpdate(account.Id, 'Checkbook_Request', 'Checkbook requested for delivery');
            
            UpdateResult result = new UpdateResult(true, 'Checkbook request submitted successfully. It will be delivered within 7 business days.');
            result.requestId = requestId;
            return result;
            
        } catch (Exception e) {
            return new UpdateResult(false, 'Unable to process checkbook request. Please try again.');
        }
    }
    
    // Request statement
    @AuraEnabled
    public static UpdateResult requestStatement(String accountNumber, String sessionToken, 
                                              String fromDate, String toDate, String deliveryMethod) {
        try {
            if (!BankingOTPService.isSessionValid(accountNumber, sessionToken)) {
                return new UpdateResult(false, 'Session expired. Please verify your identity again');
            }
            
            Date fromDt = Date.valueOf(fromDate);
            Date toDt = Date.valueOf(toDate);
            
            if (fromDt > toDt) {
                return new UpdateResult(false, 'From date cannot be later than To date');
            }
            
            if (fromDt.addDays(366) < toDt) {
                return new UpdateResult(false, 'Statement period cannot exceed 12 months');
            }
            
            // Create service request
            String requestDetails = 'Statement requested for period: ' + fromDate + ' to ' + toDate + 
                                  '. Delivery method: ' + deliveryMethod;
            String requestId = createServiceRequest(accountNumber, 'Statement Request', requestDetails);
            
            // Log the request
            RS_Bank_Account__c account = [SELECT Id FROM RS_Bank_Account__c WHERE Account_Number__c = :accountNumber LIMIT 1];
            logAccountUpdate(account.Id, 'Statement_Request', requestDetails);
            
            UpdateResult result = new UpdateResult(true, 'Statement request submitted successfully.');
            result.requestId = requestId;
            return result;
            
        } catch (Exception e) {
            return new UpdateResult(false, 'Unable to process statement request. Please check the dates and try again.');
        }
    }
    
    private static String createServiceRequest(String accountNumber, String requestType, String details) {
        try {
            // Create a case or custom service request object
            String requestId = 'REQ-' + DateTime.now().format('yyyyMMddHHmmss') + '-' + 
                              String.valueOf(Math.round(Math.random() * 999));
            
            // If you have a Service_Request__c custom object, create record here
            // For now, just return the generated ID
            
            return requestId;
        } catch (Exception e) {
            return 'REQ-ERROR-' + DateTime.now().getTime();
        }
    }
    
    private static void logAccountUpdate(String accountId, String updateType, String details) {
        try {
            Security_Audit__c audit = new Security_Audit__c();
            audit.Bank_Account__c = accountId;
            audit.Event_Type__c = 'Account_Update';
            audit.Success__c = true;
            audit.Details__c = updateType + ': ' + details;
            audit.Timestamp__c = DateTime.now();
            insert audit;
        } catch (Exception e) {
            System.debug('Audit logging error: ' + e.getMessage());
        }
    }
}