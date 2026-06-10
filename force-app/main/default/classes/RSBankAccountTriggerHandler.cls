public class RSBankAccountTriggerHandler {
    
    public static void handleAfterInsert(List<RS_Bank_Account__c> newBankAccounts) {
        // Create users first, then send emails with user details
        createCustomerUsersAndSendEmails(newBankAccounts);
    }
    
    // Method to create users and send comprehensive welcome emails
    private static void createCustomerUsersAndSendEmails(List<RS_Bank_Account__c> bankAccounts) {
        // Use future method to handle user creation and email sending
        Set<Id> accountIds = new Set<Id>();
        for (RS_Bank_Account__c acc : bankAccounts) {
            if (String.isNotBlank(acc.Customer_Email__c) && String.isNotBlank(acc.Name)) {
                accountIds.add(acc.Id);
            }
        }
        
        if (!accountIds.isEmpty()) {
            processAccountsAsync(accountIds);
        }
    }
    
    @future
    public static void processAccountsAsync(Set<Id> bankAccountIds) {
        // Get the Chatter Free profile
        Profile chatterFreeProfile;
        try {
            chatterFreeProfile = [SELECT Id FROM Profile WHERE Name = 'Chatter Free User Clone' LIMIT 1];
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Chatter Free User profile not found: ' + e.getMessage());
            return;
        }
        
        // Query the bank accounts with all required fields
        List<RS_Bank_Account__c> bankAccounts = [
            SELECT Id, Name, Customer_Email__c, Account_Number__c, 
                   Account_Type__c, Balance__c, Customer_Phone__c, Nominee__c
            FROM RS_Bank_Account__c 
            WHERE Id IN :bankAccountIds 
            AND Customer_Email__c != null 
            AND Name != null
        ];
        
        List<User> usersToCreate = new List<User>();
        Map<Id, String> accountIdToUsernameMap = new Map<Id, String>();
        
        // Step 1: Create Users
        for (RS_Bank_Account__c account : bankAccounts) {
            // Check if user already exists with this email
            List<User> existingUsers = [SELECT Id FROM User WHERE Email = :account.Customer_Email__c AND IsActive = true LIMIT 1];
            System.debug('existingUsers--'+existingUsers);
            if (existingUsers.isEmpty()) {
                String username = account.Customer_Email__c + '.rsbank';
                System.debug('username--'+username);
                User newUser = new User();
                newUser.Username = username;
                newUser.Email = account.Customer_Email__c;
                newUser.FirstName = getFirstName(account.Name);
                newUser.LastName = getLastName(account.Name);
                newUser.Alias = generateAlias(account.Name);
                newUser.ProfileId = chatterFreeProfile.Id;
                newUser.TimeZoneSidKey = 'Asia/Kolkata';
                newUser.LocaleSidKey = 'en_IN';
                newUser.EmailEncodingKey = 'UTF-8';
                newUser.LanguageLocaleKey = 'en_US';
                newUser.IsActive = true;
                newUser.Phone = account.Customer_Phone__c;
                newUser.CommunityNickname = generateCommunityNickname(account.Name, account.Id);
                
                usersToCreate.add(newUser);
                accountIdToUsernameMap.put(account.Id, username);
            } else {
                System.debug('User already exists for email: ' + account.Customer_Email__c);
            }
        }
        
        // Insert users
        Map<Id, User> accountIdToUserMap = new Map<Id, User>();
        if (!usersToCreate.isEmpty()) {
            try {
                Database.SaveResult[] results = Database.insert(usersToCreate, false);
                System.debug('results--'+results);
                
                Integer index = 0;
                for (Database.SaveResult result : results) {
                    if (result.isSuccess()) {
                        User createdUser = usersToCreate[index];
                        for (Id accountId : accountIdToUsernameMap.keySet()) {
                            if (accountIdToUsernameMap.get(accountId) == createdUser.Username) {
                                accountIdToUserMap.put(accountId, createdUser);
                                break;
                            }
                        }
                        System.debug('Successfully created user: ' + createdUser.Username);
                    } else {
                        for (Database.Error error : result.getErrors()) {
                            System.debug(LoggingLevel.ERROR, 'Error creating user: ' + error.getMessage());
                        }
                    }
                    index++;
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error in user creation: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
            }
        }
        
        // Step 2: Send comprehensive welcome emails
        sendComprehensiveWelcomeEmails(bankAccounts, accountIdToUserMap);
    }
    
    // Method to send detailed welcome emails
    private static void sendComprehensiveWelcomeEmails(List<RS_Bank_Account__c> bankAccounts, Map<Id, User> accountIdToUserMap) {
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        
        for (RS_Bank_Account__c account : bankAccounts) {
            if (String.isNotBlank(account.Customer_Email__c) && account.Customer_Email__c.contains('@')) {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new String[]{account.Customer_Email__c});
                email.setSubject('Welcome to RS Banking Corporation'); // Use custom label
                
                User createdUser = accountIdToUserMap.get(account.Id);
                String emailBody = buildWelcomeEmailBody(account, createdUser);
                String plainTextBody = buildPlainTextEmailBody(account, createdUser);
                
                if (String.isNotBlank(emailBody) && emailBody.length() <= 32000) {
                    email.setHtmlBody(emailBody);
                } else {
                    System.debug(LoggingLevel.ERROR, 'Invalid or oversized HTML email body for account ' + account.Id + ': Size=' + (emailBody == null ? 'null' : String.valueOf(emailBody.length())));
					continue;
                }
                
                if (String.isNotBlank(plainTextBody)) {
                    email.setPlainTextBody(plainTextBody);
                }
                
                email.setSaveAsActivity(false);
                emailsToSend.add(email);
                System.debug('Prepared email for account ' + account.Id + ' with body length: ' + emailBody.length());
            } else {
                System.debug(LoggingLevel.WARN, 'Invalid or missing email for account ' + account.Id);
            }
        }
        
        if (!emailsToSend.isEmpty()) {
            if (emailsToSend.size() > Limits.getLimitEmailInvocations()) {
                System.debug(LoggingLevel.ERROR, 'Cannot send ' + emailsToSend.size() + ' emails: Exceeds governor limit of ' + Limits.getLimitEmailInvocations());
                return;
            }
            
            try {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(emailsToSend);
                System.debug('results--'+results);
                Integer successCount = 0;
                for (Messaging.SendEmailResult result : results) {
                    if (result.isSuccess()) {
                        successCount++;
                    } else {
                        System.debug(LoggingLevel.ERROR, 'Email failed: ' + result.getErrors()[0].getMessage());
                    }
                }
                System.debug('Successfully sent ' + successCount + ' out of ' + emailsToSend.size() + ' emails');
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error sending emails: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
            }
        }
    }
    
    // Method to build comprehensive HTML email body
    private static String buildWelcomeEmailBody(RS_Bank_Account__c account, User createdUser) {
        String emailBody = '<html><body style="font-family: Arial, sans-serif; color: #333; margin: 0; padding: 0;">';
        
        // Header
        emailBody += '<table width="100%" bgcolor="#1f4e79" style="color: white; padding: 20px; text-align: center;"><tr><td>';
        emailBody += '<h1>Welcome to RS Banking Corporation!</h1>';
        emailBody += '</td></tr></table>';
        
        // Greeting
        emailBody += '<table width="100%" style="padding: 20px;"><tr><td>';
        emailBody += '<h2>Dear ' + String.escapeSingleQuotes(account.Name) + ',</h2>';
        emailBody += '<p>Congratulations! Your bank account has been successfully created with RS Banking Corporation. We are delighted to welcome you to our banking family.</p>';
        
        // Account Details Section
        emailBody += '<table width="100%" bgcolor="#f8f9fa" style="padding: 15px; margin: 20px 0; border-left: 4px solid #1f4e79;"><tr><td>';
        emailBody += '<h3 style="color: #1f4e79;">Your Account Details:</h3>';
        emailBody += '<table width="100%" style="border-collapse: collapse;">';
        emailBody += '<tr><td style="padding: 8px 0; font-weight: bold;">Account Holder Name:</td><td>' + String.escapeSingleQuotes(account.Name) + '</td></tr>';
        emailBody += '<tr><td style="padding: 8px 0; font-weight: bold;">Account Number:</td><td>' + (account.Account_Number__c != null ? String.escapeSingleQuotes(account.Account_Number__c) : 'Not provided') + '</td></tr>';
        emailBody += '<tr><td style="padding: 8px 0; font-weight: bold;">Account Type:</td><td>' + (account.Account_Type__c != null ? String.escapeSingleQuotes(account.Account_Type__c) : 'Savings') + '</td></tr>';
        emailBody += '<tr><td style="padding: 8px 0; font-weight: bold;">Email:</td><td>' + String.escapeSingleQuotes(account.Customer_Email__c) + '</td></tr>';
        emailBody += '<tr><td style="padding: 8px 0; font-weight: bold;">Contact:</td><td>' + (account.Customer_Phone__c != null ? String.escapeSingleQuotes(account.Customer_Phone__c) : 'Not provided') + '</td></tr>';
        emailBody += '<tr><td style="padding: 8px 0; font-weight: bold;">Current Balance:</td><td>₹ ' + (account.Balance__c != null ? String.valueOf(account.Balance__c) : '0.00') + '</td></tr>';
        emailBody += '<tr><td style="padding: 8px 0; font-weight: bold;">Nominee:</td><td>' + (account.Nominee__c != null ? String.escapeSingleQuotes(account.Nominee__c) : 'Not assigned') + '</td></tr>';
        emailBody += '</table></td></tr></table>';
        
        // Online Banking Access Section
        if (createdUser != null) {
            emailBody += '<table width="100%" bgcolor="#e8f4f8" style="padding: 15px; margin: 20px 0; border-left: 4px solid #17a2b8;"><tr><td>';
            emailBody += '<h3 style="color: #17a2b8;">Online Banking Access:</h3>';
            emailBody += '<p><strong>Username:</strong> ' + String.escapeSingleQuotes(createdUser.Username) + '</p>';
            emailBody += '<p><strong>Login Portal:</strong> <a href="' + 'https://apliteinfosolution-c-dev-ed.develop.my.site.com/myrsbank' + '" style="color: #17a2b8;">RS Banking Customer Portal</a></p>';
            emailBody += '</td></tr></table>';
            System.debug('Inside If');
        } else {
            emailBody += '<table width="100%" bgcolor="#e8f4f8" style="padding: 15px; margin: 20px 0; border-left: 4px solid #17a2b8;"><tr><td>';
            emailBody += '<h3 style="color: #17a2b8;">Online Banking Access:</h3>';
            emailBody += '<p>User creation is pending. You will receive login details once your account is fully set up.</p>';
            emailBody += '</td></tr></table>';
            System.debug('Inside else');
        }
        
        // Password Reset Instructions
        emailBody += '<table width="100%" bgcolor="#fff3cd" style="padding: 15px; margin: 20px 0; border-left: 4px solid #ffc107;"><tr><td>';
        emailBody += '<h3 style="color: #856404;">🔐 Important: Set Your Password</h3>';
        emailBody += '<p><strong>You will receive a separate password reset email shortly.</strong> Please follow these steps:</p>';
        emailBody += '<ol>';
        emailBody += '<li>Check your email for a "Password Reset" message</li>';
        emailBody += '<li>Click on the reset link and create a strong password</li>';
        emailBody += '<li>Visit our customer portal and login with your username and new password</li>';
        emailBody += '<li>Complete your profile setup for enhanced security</li>';
        emailBody += '</ol></td></tr></table>';
        
        // Services Available Section
        emailBody += '<table width="100%" bgcolor="#d1ecf1" style="padding: 15px; margin: 20px 0; border-left: 4px solid #0dcaf0;"><tr><td>';
        emailBody += '<h3 style="color: #055160;">🚀 Services Available Through Our Portal:</h3>';
        emailBody += '<table width="100%" style="margin-top: 15px;">';
        String[] services = new String[]{
            '💰 Check Account Balance',
            '🔄 Fund Transfers',
            '📝 Update PAN Details',
            '👥 Nominee Management',
            '📧 Email & Phone Updates',
            '📊 Bank Statements',
            '🏦 Account Types Information',
            '💳 Loan Services',
            '💳 Card Services',
            '🛡️ Insurance Plans',
            '📈 Investment Options',
            '🤖 24/7 AgentForce Assistant'
        };
        for (Integer i = 0; i < services.size(); i++) {
            emailBody += '<tr><td style="padding: 5px;">' + services[i] + '</td></tr>';
        }
        emailBody += '</table></td></tr></table>';
        
        // AgentForce Information
        emailBody += '<table width="100%" bgcolor="#d4edda" style="padding: 15px; margin: 20px 0; border-left: 4px solid #28a745;"><tr><td>';
        emailBody += '<h3 style="color: #155724;">🤖 Meet Your Digital Banking Assistant - AgentForce</h3>';
        emailBody += '<p>Our advanced AI-powered AgentForce is available 24/7 to help you with:</p>';
        emailBody += '<ul>';
        emailBody += '<li>Instant balance inquiries and transaction history</li>';
        emailBody += '<li>Quick fund transfers and bill payments</li>';
        emailBody += '<li>Account management and profile updates</li>';
        emailBody += '<li>Product information and recommendations</li>';
        emailBody += '<li>General banking queries and support</li>';
        emailBody += '</ul></td></tr></table>';
        
        // Important Notes
        emailBody += '<table width="100%" bgcolor="#f8d7da" style="padding: 15px; margin: 20px 0; border-left: 4px solid #dc3545;"><tr><td>';
        emailBody += '<h3 style="color: #721c24;">⚠️ Important Security Notes:</h3>';
        emailBody += '<ul>';
        emailBody += '<li>Never share your login credentials with anyone</li>';
        emailBody += '<li>Always logout after completing your banking session</li>';
        emailBody += '<li>Use strong passwords and change them regularly</li>';
        emailBody += '<li>Contact us immediately if you notice any suspicious activity</li>';
        emailBody += '</ul></td></tr></table>';
        
        // Contact Information
        emailBody += '<table width="100%" bgcolor="#f8f9fa" style="padding: 15px; margin: 20px 0;"><tr><td>';
        emailBody += '<h3 style="color: #1f4e79;">📞 Need Help?</h3>';
        emailBody += '<p>Our customer support team is available:</p>';
        emailBody += '<ul>';
        emailBody += '<li><strong>Phone:</strong> ' + '8827613672' + '</li>';
        emailBody += '<li><strong>Email:</strong> ' + 'support@rsbank.com' + '</li>';
        emailBody += '<li><strong>Working Hours:</strong> Monday to Saturday, 9:00 AM - 6:00 PM</li>';
        emailBody += '</ul></td></tr></table>';
        
        // Footer
        emailBody += '<table width="100%" bgcolor="#1f4e79" style="color: white; padding: 20px; text-align: center; margin-top: 30px;"><tr><td>';
        emailBody += '<p>Thank you for choosing RS Banking Corporation!</p>';
        emailBody += '<p style="font-size: 12px;">This is an automated message. Please do not reply to this email.</p>';
        emailBody += '<p style="font-size: 12px;">© 2025 RS Banking Corporation. All rights reserved.</p>';
        emailBody += '</td></tr></table>';
        
        emailBody += '</body></html>';
        
        System.debug('Generated email body for account ' + account.Id + ': ' + emailBody);
        return emailBody;
    }
    
    // Method to build plain text email body
    private static String buildPlainTextEmailBody(RS_Bank_Account__c account, User createdUser) {
        String plainTextBody = 'Welcome to RS Banking Corporation!\n\n';
        plainTextBody += 'Dear ' + account.Name + ',\n\n';
        plainTextBody += 'Congratulations! Your bank account has been successfully created with RS Banking Corporation. We are delighted to welcome you to our banking family.\n\n';
        
        // Account Details
        plainTextBody += 'Your Account Details:\n';
        plainTextBody += 'Account Holder Name: ' + account.Name + '\n';
        plainTextBody += 'Account Number: ' + (account.Account_Number__c != null ? account.Account_Number__c : 'Not provided') + '\n';
        plainTextBody += 'Account Type: ' + (account.Account_Type__c != null ? account.Account_Type__c : 'Savings') + '\n';
        plainTextBody += 'Email: ' + account.Customer_Email__c + '\n';
        plainTextBody += 'Contact: ' + (account.Customer_Phone__c != null ? account.Customer_Phone__c : 'Not provided') + '\n';
        plainTextBody += 'Current Balance: ₹ ' + (account.Balance__c != null ? String.valueOf(account.Balance__c) : '0.00') + '\n';
        plainTextBody += 'Nominee: ' + (account.Nominee__c != null ? account.Nominee__c : 'Not assigned') + '\n\n';
        
        // Online Banking Access
        if (createdUser != null) {
            plainTextBody += 'Online Banking Access:\n';
            plainTextBody += 'Username: ' + createdUser.Username + '\n';
            plainTextBody += 'Login Portal: ' + 'www.rsbank.com' + '\n\n';
        } else {
            plainTextBody += 'Online Banking Access:\n';
            plainTextBody += 'User creation is pending. You will receive login details once your account is fully set up.\n\n';
        }
        
        // Password Reset Instructions
        plainTextBody += 'Important: Set Your Password\n';
        plainTextBody += 'You will receive a separate password reset email shortly. Please follow these steps:\n';
        plainTextBody += '1. Check your email for a "Password Reset" message\n';
        plainTextBody += '2. Click on the reset link and create a strong password\n';
        plainTextBody += '3. Visit our customer portal and login with your username and new password\n';
        plainTextBody += '4. Complete your profile setup for enhanced security\n\n';
        
        // Services Available
        plainTextBody += 'Services Available Through Our Portal:\n';
        String[] services = new String[]{
            'Check Account Balance',
            'Fund Transfers',
            'Update PAN Details',
            'Nominee Management',
            'Email & Phone Updates',
            'Bank Statements',
            'Account Types Information',
            'Loan Services',
            'Card Services',
            'Insurance Plans',
            'Investment Options',
            '24/7 AgentForce Assistant'
        };
        for (String service : services) {
            plainTextBody += '- ' + service + '\n';
        }
        plainTextBody += '\n';
        
        // AgentForce Information
        plainTextBody += 'Meet Your Digital Banking Assistant - AgentForce\n';
        plainTextBody += 'Our advanced AI-powered AgentForce is available 24/7 to help you with:\n';
        plainTextBody += '- Instant balance inquiries and transaction history\n';
        plainTextBody += '- Quick fund transfers and bill payments\n';
        plainTextBody += '- Account management and profile updates\n';
        plainTextBody += '- Product information and recommendations\n';
        plainTextBody += '- General banking queries and support\n\n';
        
        // Important Notes
        plainTextBody += 'Important Security Notes:\n';
        plainTextBody += '- Never share your login credentials with anyone\n';
        plainTextBody += '- Always logout after completing your banking session\n';
        plainTextBody += '- Use strong passwords and change them regularly\n';
        plainTextBody += '- Contact us immediately if you notice any suspicious activity\n\n';
        
        // Contact Information
        plainTextBody += 'Need Help?\n';
        plainTextBody += 'Our customer support team is available:\n';
        plainTextBody += 'Phone: ' + '8827613672' + '\n';
        plainTextBody += 'Email: ' + 'support@rsbank.com' + '\n';
        plainTextBody += 'Working Hours: Monday to Saturday, 9:00 AM - 6:00 PM\n\n';
        
        // Footer
        plainTextBody += 'Thank you for choosing RS Banking Corporation!\n';
        plainTextBody += 'This is an automated message. Please do not reply to this email.\n';
        plainTextBody += '© 2025 RS Banking Corporation. All rights reserved.\n';
        
        return plainTextBody;
    }
    
    // Helper method to extract first name
    private static String getFirstName(String fullName) {
        if (String.isBlank(fullName)) return 'Customer';
        List<String> nameParts = fullName.trim().split('\\s+');
        return nameParts[0];
    }
    
    // Helper method to extract last name
    private static String getLastName(String fullName) {
        if (String.isBlank(fullName)) return 'User';
        List<String> nameParts = fullName.trim().split('\\s+');
        if (nameParts.size() > 1) {
            return nameParts[nameParts.size() - 1];
        }
        return 'User';
    }
    
    // Helper method to generate alias (max 8 characters)
    private static String generateAlias(String fullName) {
        if (String.isBlank(fullName)) return 'RSUser';
        String alias = fullName.replaceAll('[^a-zA-Z0-9]', '').toLowerCase();
        return alias.length() > 8 ? alias.substring(0, 8) : alias;
    }
    
    // Helper method to generate community nickname (must be unique)
   /* private static String generateCommunityNickname(String fullName, Id accountId) {
        String baseNickname = fullName.replaceAll('[^a-zA-Z0-9]', '').toLowerCase();
        String accountSuffix = String.valueOf(accountId).substring(13, 17);
        String nickname = baseNickname + accountSuffix;
        
        if (nickname.length() > 40) {
            nickname = nickname.substring(0, 36) + accountSuffix;
        }
        
        return nickname;
    }*/
    private static String generateCommunityNickname(String fullName, Id accountId) {
    // Step 1: Clean up full name to only alphanumeric, lowercase
    String baseNickname = fullName.replaceAll('[^a-zA-Z0-9]', '').toLowerCase();
    String accountSuffix = String.valueOf(accountId).substring(0, 4);

    // Step 2: Add a 4-digit random suffix (always positive, padded with 0s if short)
    Integer rand = Math.mod(Math.abs(Crypto.getRandomInteger()), 10000);
    String randomSuffix = String.valueOf(rand);
    while (randomSuffix.length() < 4) {
        randomSuffix = '0' + randomSuffix;
    }

    // Initial nickname
    String nickname = baseNickname + accountSuffix + randomSuffix;

    // Step 3: Trim to max 40 chars
    if (nickname.length() > 40) {
        nickname = nickname.substring(0, 40);
    }

    // Step 4: Ensure uniqueness
    String finalNickname = nickname;
    Integer counter = 1;
    while ([SELECT COUNT() FROM User WHERE CommunityNickname = :finalNickname] > 0) {
        finalNickname = nickname;
        if (finalNickname.length() + String.valueOf(counter).length() > 40) {
            finalNickname = finalNickname.substring(0, 40 - String.valueOf(counter).length());
        }
        finalNickname += String.valueOf(counter);
        counter++;
    }

    return finalNickname;
}


}