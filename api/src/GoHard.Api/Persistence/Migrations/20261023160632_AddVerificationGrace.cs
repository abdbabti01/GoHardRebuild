using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GoHard.Api.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddVerificationGrace : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "VerificationGraceFromUtc",
                table: "Users",
                type: "timestamp with time zone",
                nullable: true);

            // The rollout cutoff, recorded once: every account unverified at this moment gets its grace period from
            // now (Auth:VerificationGraceDays). Accounts created after this, by any instance, have none and must verify.
            // Never re-run: Down forgets the cutoff, and applying Up again would start every grace period over.
            migrationBuilder.Sql("""UPDATE "Users" SET "VerificationGraceFromUtc" = now() WHERE "EmailVerifiedAtUtc" IS NULL;""");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "VerificationGraceFromUtc",
                table: "Users");
        }
    }
}
