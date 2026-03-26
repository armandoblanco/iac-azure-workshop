using System.Collections.Concurrent;
using BankApi.Models;

namespace BankApi.Services;

public class BankService
{
    private readonly ConcurrentDictionary<Guid, Customer> _customers = new();
    private readonly ConcurrentDictionary<Guid, Account> _accounts = new();
    private int _accountCounter = 1000;

    public BankService()
    {
        // Seed demo data
        var customerId = Guid.NewGuid();
        _customers[customerId] = new Customer(customerId, "Ana García", "ana.garcia@contoso.com", "+52-55-1234-5678");

        var accountId = Guid.NewGuid();
        var accountNumber = $"ACC-{Interlocked.Increment(ref _accountCounter):D6}";
        _accounts[accountId] = new Account(accountId, customerId, accountNumber, 15000.00m, AccountType.Savings);
    }

    // Customers
    public IEnumerable<Customer> GetCustomers() => _customers.Values;

    public Customer? GetCustomer(Guid id) =>
        _customers.TryGetValue(id, out var c) ? c : null;

    public Customer CreateCustomer(CreateCustomerRequest req)
    {
        var customer = new Customer(Guid.NewGuid(), req.Name, req.Email, req.Phone);
        _customers[customer.Id] = customer;
        return customer;
    }

    public bool DeleteCustomer(Guid id) => _customers.TryRemove(id, out _);

    // Accounts
    public IEnumerable<Account> GetAccounts(Guid? customerId = null) =>
        customerId.HasValue
            ? _accounts.Values.Where(a => a.CustomerId == customerId.Value)
            : _accounts.Values;

    public Account? GetAccount(Guid id) =>
        _accounts.TryGetValue(id, out var a) ? a : null;

    public Account? CreateAccount(CreateAccountRequest req)
    {
        if (!_customers.ContainsKey(req.CustomerId)) return null;

        var number = $"ACC-{Interlocked.Increment(ref _accountCounter):D6}";
        var account = new Account(Guid.NewGuid(), req.CustomerId, number, req.InitialDeposit, req.Type);
        _accounts[account.Id] = account;
        return account;
    }

    public bool DeleteAccount(Guid id) => _accounts.TryRemove(id, out _);
}
