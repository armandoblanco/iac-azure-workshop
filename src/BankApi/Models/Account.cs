namespace BankApi.Models;

public record Account(
    Guid Id,
    Guid CustomerId,
    string AccountNumber,
    decimal Balance,
    AccountType Type
);

public record CreateAccountRequest(
    Guid CustomerId,
    AccountType Type,
    decimal InitialDeposit
);

public enum AccountType
{
    Checking,
    Savings
}
