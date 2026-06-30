import { LightningElement, api } from 'lwc';

import transferFunds
    from '@salesforce/apex/RSBankDashboardController.transferFunds';

import { ShowToastEvent }
    from 'lightning/platformShowToastEvent';

export default class RsTransferFunds extends LightningElement {

    @api accountNumber;

    toAccountNumber = '';

    amount;

    description = '';

    isLoading = false;

    handleToAccountChange(event) {

        this.toAccountNumber = event.target.value;

    }

    handleAmountChange(event) {

        this.amount = Number(event.target.value);

    }

    handleDescriptionChange(event) {

        this.description = event.target.value;

    }

    handleClose() {

        this.dispatchEvent(
            new CustomEvent('close')
        );

    }

    async handleTransfer() {

        if (!this.toAccountNumber) {

            this.showToast(
                'Error',
                'Destination Account is required.',
                'error'
            );

            return;

        }

        if (!this.amount || this.amount <= 0) {

            this.showToast(
                'Error',
                'Please enter valid amount.',
                'error'
            );

            return;

        }

        this.isLoading = true;

        try {

            const result = await transferFunds({

                fromAccountNumber: this.accountNumber,

                toAccountNumber: this.toAccountNumber,

                amount: this.amount,

                description: this.description

            });

            if (result.success) {

                this.showToast(

                    'Success',

                    result.message,

                    'success'

                );

                this.dispatchEvent(

                    new CustomEvent('success')

                );

            }
            else {

                this.showToast(

                    'Transfer Failed',

                    result.message,

                    'error'

                );

            }

        }
        catch (error) {

            this.showToast(

                'Error',

                error.body?.message || error.message,

                'error'

            );

        }
        finally {

            this.isLoading = false;

        }

    }

    showToast(title, message, variant) {

        this.dispatchEvent(

            new ShowToastEvent({

                title,

                message,

                variant

            })

        );

    }

}