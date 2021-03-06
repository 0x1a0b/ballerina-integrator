// Copyright (c) 2018 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/config;
import ballerina/jsonutils;
import ballerina/lang.'int as ints;
import ballerina/log;
import ballerina/transactions;
import ballerinax/java.jdbc;

// 'jdbc:Client'.
jdbc:Client bankDB = new({
    url: config:getAsString("DATABASE_URL", "jdbc:mysql://127.0.0.1:3306/bankDB"),
    username: config:getAsString("DATABASE_USERNAME", "root"),
    password: config:getAsString("DATABASE_PASSWORD", "root"),
    dbOptions: { useSSL: false }
});

// Function to add users to 'ACCOUNT' table of 'bankDB' database.
public function createAccount(string name) returns @tainted int|error {
    // Insert query.
    var updateRet = bankDB->update("INSERT INTO ACCOUNT (USERNAME, BALANCE) VALUES (?, ?)", name, 0);
    if (updateRet is error) {
        log:printError("Error occurred during database operation", err = updateRet);
        return updateRet;
    }
    // Get the primary key of the last insertion (Auto incremented value).
    var selectRet = bankDB->select("SELECT LAST_INSERT_ID() AS ACCOUNT_ID from ACCOUNT where ?", (), 1);
    int|error retVal = -1;
    if (selectRet is table<record {}>) {
        // convert the table to json
        var jsonConvertRet = jsonutils:fromTable(selectRet);
        int|error returnVal;
        map<json>[] jsonConvert = <map<json>[]>jsonConvertRet;
        retVal = ints:fromString(jsonConvert[0]["ACCOUNT_ID"].toString());
        if (retVal is int) {
            log:printInfo("Account ID for user: '" + name.toString() + "': " + retVal.toString());
        } else {
            log:printError("Error occurred during JSON conversion", err = retVal);
        }
        // Since we are not fully iterating the json value converted from the table we need to explicitly close the table
        // to avoid connection leak. If the json was fully iterated, the table would also have been fully iterated and
        // streamed out and then the connection would have been automatically closed.
        selectRet.close();
    } else {
        retVal = selectRet;
        log:printError("Error occurred during database operation", err = selectRet);
    }
    // Return the primary key, which will be the account number of the account or an error in case of a failure
    return retVal;
}

// Function to verify an account whether it exists or not.
public function verifyAccount(int accId) returns @tainted boolean|error {
    log:printInfo("Verifying whether account ID " + accId.toString() + " exists");
    // SQL query parameters.
    // Select query to check whether account exists.
    var selectRet = bankDB->select("SELECT COUNT(*) AS COUNT FROM ACCOUNT WHERE ID = ?", (), accId);
    boolean|error retVal = false;
    if (selectRet is table<record {}>) {
        // convert the table to json.
        var jsonConvertRet = jsonutils:fromTable(selectRet);
        map<json>[] jsonConvert = <map<json>[]>jsonConvertRet;
        // convert the json to int.
        int|error count = ints:fromString(jsonConvert[0]["COUNT"].toString());
        // Return a boolean, which will be true if account exists; false otherwise.
        if (count is int) {
            if (count != 0) {
                retVal = true;
            } else {
                retVal = false;
            }  
        } else {
            retVal = count;
        }
        // Since we are not fully iterating the json value converted from the table we need to explicitly close the table
        // to avoid connection leak. If the json was fully iterated, the table would also have been fully iterated and
        // streamed out and then the connection would have been automatically closed.
        selectRet.close();
    } else {
        retVal = selectRet;
    }
    return retVal;
}

// Function to check balance in an account.
public function checkBalance(int accId) returns @tainted int|error {
    // Verify account whether it exists and return an error if not.
    var accountVerificationRet = verifyAccount(accId);
    if (accountVerificationRet is error) {
        return accountVerificationRet;
    } else {
        if (!accountVerificationRet) {
            error err = error("Error: Account does not exist");
            return err;
        }
    }
    int|error retVal = -1;
    // Select query to get balance.
    var selectRet = bankDB->select("SELECT BALANCE FROM ACCOUNT WHERE ID = ?", (), accId);
    if (selectRet is table<record {}>) {
        // convert the table to json.
        var jsonConvertRet = jsonutils:fromTable(selectRet);
        map<json>[] jsonConvert = <map<json>[]>jsonConvertRet;
        // convert the json to int.
        int|error balance = ints:fromString(jsonConvert[0]["BALANCE"].toString());
        if (balance is int) {
            log:printInfo("Available balance in account ID " + accId.toString() + ": " + balance.toString());
            retVal = balance;
        } else {
            retVal = balance;
        }
        // Since we are not fully iterating the json value converted from the table we need to explicitly close the table
        // to avoid connection leak. If the json was fully iterated, the table would also have been fully iterated and
        // streamed out and then the connection would have been automatically closed.
        selectRet.close();
    } else {
        retVal = selectRet;
    }
    // Return the balance or error in case of a failure.
    return retVal;
}

// Function to deposit money to an account.
public function depositMoney(int accId, int amount) returns @tainted error|() {
    // Check whether the amount specified is valid and return an error if not.
    if (amount <= 0) {
        error err = error("Error: Invalid amount");
        return err;
    }
    var accountVerificationRet = verifyAccount(accId);
    if (accountVerificationRet is error) {
        return accountVerificationRet;
    } else {
        if (!accountVerificationRet) {
            // Verify account whether it exists and return an error if not.
            error err = error("Error: Account does not exist");
            return err;
        }
    }
    log:printInfo("Depositing money to account ID: " + accId.toString());
    // Update query to increase the current balance.
    var updateRet = bankDB->update("UPDATE ACCOUNT SET BALANCE = (BALANCE + ?) WHERE ID = ?", amount, accId);
    if (updateRet is jdbc:UpdateResult) {
        log:printInfo("$" + amount.toString() + " has been deposited to account ID " + accId.toString());
    } else {
        return updateRet;
    }
    return;
}

// Function to withdraw money from an account.
public function withdrawMoney(int accId, int amount) returns @tainted error|() {
    // Check whether the amount specified is valid and return an error if not.
    if (amount <= 0) {
        error err = error("Error: Invalid amount");
        return err;
    }
    // Check current balance.
    var balanceVal = checkBalance(accId);
    if (balanceVal is int) {
        // Check whether the user has enough money to withdraw the requested amount and return an error if not.
        if (balanceVal < amount) {
            error err = error("Error: Not enough balance");
            return err;
        }
    } else {
        return balanceVal;
    }
    log:printInfo("Withdrawing money from account ID: " + accId.toString());
    // Update query to reduce the current balance.
    var updateRet = bankDB->update("UPDATE ACCOUNT SET BALANCE = (BALANCE - ?) WHERE ID = ?", amount, accId);
    if (updateRet is jdbc:UpdateResult) {
        log:printInfo("$" + amount.toString() + " has been withdrawn from account ID " + accId.toString());
    } else {
        return updateRet;
    }
    return;
}

// Function to transfer money from one account to another.
public function transferMoney(int fromAccId, int toAccId, int amount) returns boolean {
    boolean isSuccessful = false;
    log:printInfo("Initiating transaction");
    // Transaction block - Ensures the 'ACID' properties.
    // Withdraw and deposit should happen as a transaction when transferring money from one account to another.
    // Here, the reason for switching off the 'retries' option is, in failing scenarios almost all the time
    // transaction fails due to erroneous operations triggered by the users.
    transaction with retries = 0 {
        // Withdraw money from transferor's account.
        var withdrawRet = withdrawMoney(fromAccId, amount);
        if (withdrawRet is ()) {
            var depositRet = depositMoney(toAccId, amount);
            if (depositRet is ()) {
                isSuccessful = true;
            } else {
                log:printError("Error while depositing the money: " + depositRet.reason());
                // Abort transaction if deposit fails.
                log:printError("Failed to transfer money from account ID " + fromAccId.toString() + " to account ID " +
                    toAccId.toString());
                abort;
            }
        } else {
            log:printError("Error while withdrawing the money: " + withdrawRet.reason());
            // Abort transaction if withdrawal fails.
            log:printError("Failed to transfer money from account ID " + fromAccId.toString() + " to account ID " 
                + toAccId.toString());
            abort;
        }
    } committed {
        log:printInfo("Transaction: " + transactions:getCurrentTransactionId() + " committed");
        // If transaction successful.
        log:printInfo("Successfully transferred $" + amount.toString() + " from account ID " + fromAccId.toString() 
            + " to account ID " + toAccId.toString());
    } aborted {
        log:printInfo("Transaction: " + transactions:getCurrentTransactionId() + " aborted");
    }
    return isSuccessful;
}
