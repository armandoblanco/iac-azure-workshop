namespace BankApi.Models;

public record Customer(
    Guid Id,
    string Name,
    string Email,
    string Phone
);

public record CreateCustomerRequest(
    string Name,
    string Email,
    string Phone
);
