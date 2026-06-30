import { LightningElement, api, track, wire } from 'lwc';
import userId from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/User.Name';
import getUserBankingDetails from '@salesforce/apex/UserBankingDetailsController.getUserBankingDetails';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class RsBankingDashboard extends LightningElement {
    // Public property (configurable in App Builder)
    @api customerName = 'Valued Customer';

    // Logged in user details
    @track loggedInUserId = userId;
    @track loggedInUserName;

    wiredBankingResult;

    // Wire adapter to fetch User record
    @wire(getRecord, { recordId: '$loggedInUserId', fields: [NAME_FIELD] })
    userData({ error, data }) {
        if (data) {
            this.loggedInUserName = data.fields.Name.value;
        } else if (error) {
            console.error('Error fetching user data:', error);
        }
    }

    // Clock
    @track currentTimeIST;
    clockInterval;

    // Rotating financial tips
    tips = [
        'Save at least 20% of your income every month.',
        'Track your expenses to identify savings opportunities.',
        'Invest early to take advantage of compounding.',
        'Maintain a good credit score for easy loan approvals.',
        'Diversify your investments to manage risk.',
        'Set up automatic savings for consistent growth.'
    ];
    @track currentTipIndex = 0;
    @track currentTip = this.tips[0];

    // Loan calculator
    @track loanAmount = 100000;
    @track loanInterestRate = 10;
    @track loanTerm = 5;
    @track loanTermProgress = 0;

    get formattedMonthlyPayment() {
        const monthlyRate = this.loanInterestRate / 100 / 12;
        const months = this.loanTerm * 12;
        if (monthlyRate === 0) return (this.loanAmount / months).toFixed(2);
        const monthlyPayment =
            this.loanAmount * monthlyRate /
            (1 - Math.pow(1 + monthlyRate, -months));
        return monthlyPayment.toFixed(2);
    }

    // Banking Details
    @track bankAccounts = [];
    @track transactions = [];
    @track loans = [];
    @track cards = [];
    @track transactionColumns = [
        { label: 'Transaction ID', fieldName: 'transactionId', type: 'text' },
        { label: 'Type', fieldName: 'type', type: 'text' },
        { label: 'Date', fieldName: 'transactionDate', type: 'date' },
        { label: 'Description', fieldName: 'description', type: 'text' },
        { label: 'Amount', fieldName: 'amount', type: 'currency' },
        { label: 'Status', fieldName: 'status', type: 'text' },
        { label: 'Running Balance', fieldName: 'runningBalance', type: 'currency' }
    ];

    // Loans & Credit
    @track loanBalance = 75000;
    @track creditAvailable = 15000;

    // Branch Data (for display)
    @track selectedBranchName = 'Vijaynagar, Indore Branch';
    @track selectedBranchIFSCCode = 'RSB452010';

    // Modals
    @track showModal = false;
    @track modalTitle = '';
    @track modalContent = '';

    @track showChatModal = false;
    @track chatQuery = '';
    @track agentResponse = '';
    @track showChatHistory = false;
    @track chatHistory = [];

    @track showBranchModal = false;

    @wire(getUserBankingDetails, { userId: '$loggedInUserId' })
    wiredBankingDetails(result) {

        this.wiredBankingResult = result;

        const { data, error } = result;

        if (data) {

            this.bankAccounts = data.bankAccounts || [];
            this.transactions = data.transactions || [];
            this.loans = data.loans || [];
            this.cards = data.cards || [];

        } else if (error) {

            console.error(error);

            this.bankAccounts = [];
            this.transactions = [];
            this.loans = [];
            this.cards = [];

        }

    }

    // Lifecycle
    connectedCallback() {
        this.updateClock();
        this.clockInterval = setInterval(() => this.updateClock(), 1000);
        this.rotateTips();
        setInterval(() => this.rotateTips(), 5000);
        this.updateLoanTermProgress();
        console.log('Logged in User Id:', this.loggedInUserId);
    }

    disconnectedCallback() {
        clearInterval(this.clockInterval);
    }

    updateClock() {
        const now = new Date();
        this.currentTimeIST = now.toLocaleTimeString('en-US', {
            timeZone: 'Asia/Kolkata',
            hour12: true,
            hour: 'numeric',
            minute: '2-digit',
            second: '2-digit'
        });
    }

    rotateTips() {
        this.currentTipIndex = (this.currentTipIndex + 1) % this.tips.length;
        this.currentTip = this.tips[this.currentTipIndex];
    }

    prevTip() {
        this.currentTipIndex = (this.currentTipIndex - 1 + this.tips.length) % this.tips.length;
        this.currentTip = this.tips[this.currentTipIndex];
    }

    nextTip() {
        this.currentTipIndex = (this.currentTipIndex + 1) % this.tips.length;
        this.currentTip = this.tips[this.currentTipIndex];
    }

    // Loan calculator handlers
    handleLoanAmountChange(event) {
        this.loanAmount = Number(event.target.value) || 100000;
        this.updateLoanTermProgress();
    }

    handleLoanInterestRateChange(event) {
        this.loanInterestRate = Number(event.target.value) || 10;
        this.updateLoanTermProgress();
    }

    handleLoanTermChange(event) {
        this.loanTerm = Number(event.target.value) || 5;
        this.updateLoanTermProgress();
    }

    updateLoanTermProgress() {
        const maxTerm = 30;
        this.loanTermProgress = (this.loanTerm / maxTerm) * 100;
    }

    calculateLoanPayment() {
        // No additional logic needed as formattedMonthlyPayment is reactive
    }

    // Quick Actions
    handleCheckBalance() {
        this.modalTitle = 'Account Balance';
        this.modalContent = `Your current balance is ₹${this.bankAccounts.length > 0 ? this.bankAccounts[0].balance : 'N/A'}. 
        (Logged in User: ${this.loggedInUserName || 'Loading...'})`;
        this.showModal = true;
    }
    get currentAccountNumber() {
        return this.bankAccounts?.length
            ? this.bankAccounts[0].accountNumber
            : '';
    }

    showTransferPopup = false;

    handleTransferFunds() {
        this.showTransferPopup = true;
    }

    handleTransferClose() {
        this.showTransferPopup = false;
    }

    async handleTransferSuccess() {

        this.showTransferPopup = false;

        await refreshApex(this.wiredBankingResult);

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Funds transferred successfully.',
                variant: 'success'
            })
        );

    }

    handlePayBills() {
        this.modalTitle = 'Pay Bills';
        this.modalContent = 'Pay Bills feature coming soon!';
        this.showModal = true;
    }

    handleOpenAccount() {
        this.modalTitle = 'Open Account';
        this.modalContent = 'Open Account process initiated.';
        this.showModal = true;
    }

    handleLoanApplication() {
        this.modalTitle = 'Loan Application';
        this.modalContent = 'Loan Application started.';
        this.showModal = true;
    }

    handleInvestNow() {
        this.modalTitle = 'Invest Now';
        this.modalContent = 'Investment advisory feature coming soon!';
        this.showModal = true;
    }

    // Loan & Credit Actions
    handlePayLoan() {
        this.modalTitle = 'Loan Payment';
        this.modalContent = 'Loan Payment Successful!';
        this.showModal = true;
    }

    handleViewStatement() {
        this.modalTitle = 'Credit Card Statement';
        this.modalContent = 'Credit Card Statement Downloaded.';
        this.showModal = true;
    }

    // Modal methods
    openServiceModal(event) {
        const service = event.target.dataset.service;
        this.modalTitle = `Details about ${service}`;
        this.modalContent = this.getServiceDetails(service);
        this.showModal = true;
    }

    getServiceDetails(service) {
        const details = {
            'Savings Account': 'Earn 4.5% APY with our savings account, designed for secure growth with easy access.',
            'Current Account': 'Enjoy business-friendly features with no minimum balance fees and unlimited transactions.',
            'Fixed Deposits': 'Secure your future with 6.8% APY on fixed deposits, offering guaranteed returns.',
            'Personal Loans': 'Get flexible personal loans starting at 8.5% with customizable repayment plans.',
            'Home Loans': 'Achieve home ownership with competitive rates starting at 7.2% and easy EMIs.',
            'Investment Services': 'Diversify your portfolio with expert-guided investment options tailored to your goals.'
        };
        return details[service] || `More information about ${service} will be displayed here.`;
    }

    closeModal(event) {
        console.log('Close clicked - Initiated');
        event.preventDefault();
        event.stopPropagation();
        this.handleModalClose();
    }

    // Chat Modal
    openChatModal() {
        this.showChatModal = true;
        this.showChatHistory = true;
    }

    closeChatModal(event) {
        console.log('Chat close clicked - Initiated');
        event.preventDefault();
        event.stopPropagation();
        this.handleModalClose('chat');
    }

    handleChatQueryChange(event) {
        this.chatQuery = event.target.value;
    }

    sendToAgent() {
        if (this.chatQuery) {
            this.agentResponse = `Agentforce received: "${this.chatQuery}"`;
            this.chatHistory = [
                ...this.chatHistory,
                { id: Date.now(), query: this.chatQuery, response: this.agentResponse }
            ];
            this.chatQuery = '';
        }
    }

    // Agentforce section
    @track agentQuery = '';
    handleQueryChange(event) {
        this.agentQuery = event.target.value;
    }

    handleSendToAgent() {
        if (this.agentQuery) {
            this.agentResponse = `Agentforce processed your query: "${this.agentQuery}"`;
            this.chatHistory = [
                ...this.chatHistory,
                { id: Date.now(), query: this.agentQuery, response: this.agentResponse }
            ];
            this.agentQuery = '';
        }
    }

    // Share Loan with Assistant
    shareWithAgent() {
        this.agentResponse = `Shared Loan Details: ₹${this.loanAmount}, Rate: ${this.loanInterestRate}%, Term: ${this.loanTerm} years`;
        this.chatHistory = [
            ...this.chatHistory,
            {
                id: Date.now(),
                query: 'Shared loan details',
                response: this.agentResponse
            }
        ];
    }

    // Footer Actions
    openBranchModal() {
        this.showBranchModal = true;
    }

    closeBranchModal(event) {
        console.log('Branch modal close clicked - Initiated');
        event.preventDefault();
        event.stopPropagation();
        this.handleModalClose('branch');
    }

    handleCallClick() {
        window.location.href = 'tel:8827613672';
    }

    handleEmailClick() {
        window.location.href = 'mailto:support@rsbank.com';
    }

    handleWebsiteClick() {
        window.open('https://www.rsbank.com', '_blank');
    }

    // Map Button Handler
    handleViewMap() {
        window.open('https://maps.app.goo.gl/WAKN8qQSi77zZ7eJA', '_blank');
    }

    // Centralized modal close handler
    handleModalClose(type = 'default') {
        console.log(`handleModalClose called for type: ${type}`);
        let modal, backdrop, showProperty;
        switch (type) {
            case 'chat':
                showProperty = 'showChatModal';
                break;
            case 'branch':
                showProperty = 'showBranchModal';
                break;
            default:
                showProperty = 'showModal';
        }
        // Check if modal exists in DOM
        modal = this.template.querySelector(`[data-modal-type="${type === 'default' ? 'default' : type}"]`);
        backdrop = this.template.querySelector('.slds-backdrop');
        console.log('Modal found:', !!modal, 'Backdrop found:', !!backdrop);
        if (modal && backdrop) {
            console.log('Removing classes and attributes');
            modal.classList.remove('slds-fade-in-open');
            backdrop.classList.remove('slds-backdrop_open');
            modal.setAttribute('aria-hidden', 'true');
            setTimeout(() => {
                console.log('Executing close after animation');
                this[showProperty] = false;
                if (type === 'default') {
                    this.modalTitle = '';
                    this.modalContent = '';
                } else if (type === 'chat') {
                    this.chatQuery = '';
                    this.agentResponse = '';
                }
                document.body.focus();
            }, 200); // Match SLDS fade animation duration
        } else {
            console.warn('Modal or backdrop not found, forcing close');
            this[showProperty] = false;
            if (type === 'default') {
                this.modalTitle = '';
                this.modalContent = '';
            } else if (type === 'chat') {
                this.chatQuery = '';
                this.agentResponse = '';
            }
        }
    }
}