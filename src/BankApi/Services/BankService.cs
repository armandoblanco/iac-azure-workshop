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
        var seedCustomers = new[]
        {
            ("Ana García",       "ana.garcia@contoso.com",       "+52-55-1234-5678"),
            ("Carlos Mendoza",   "carlos.mendoza@contoso.com",   "+52-55-2345-6789"),
            ("Laura Ramos",      "laura.ramos@contoso.com",      "+52-55-3456-7890"),
            ("Miguel Torres",    "miguel.torres@contoso.com",    "+52-55-4567-8901"),
            ("Sofía Herrera",    "sofia.herrera@contoso.com",    "+52-55-5678-9012"),
        };

        var seedAccounts = new[]
        {
            (AccountType.Savings,  15000.00m),
            (AccountType.Checking,  8500.50m),
            (AccountType.Savings,  22000.00m),
            (AccountType.Checking,  3200.75m),
            (AccountType.Savings,  47500.00m),
        };

        for (int i = 0; i < seedCustomers.Length; i++)
        {
            var (name, email, phone) = seedCustomers[i];
            var customerId = Guid.NewGuid();
            _customers[customerId] = new Customer(customerId, name, email, phone);

            var accountId = Guid.NewGuid();
            var accountNumber = $"ACC-{Interlocked.Increment(ref _accountCounter):D6}";
            var (type, balance) = seedAccounts[i];
            _accounts[accountId] = new Account(accountId, customerId, accountNumber, balance, type);
        }
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
