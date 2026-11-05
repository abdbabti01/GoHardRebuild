using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GoHard.Api.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddChallengeCodeDigits : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "CodeDigits",
                table: "AuthChallenges",
                type: "integer",
                nullable: false,
                defaultValue: 8);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CodeDigits",
                table: "AuthChallenges");
        }
    }
}
