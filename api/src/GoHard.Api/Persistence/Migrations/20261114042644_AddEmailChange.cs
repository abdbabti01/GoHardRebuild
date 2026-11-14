using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GoHard.Api.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddEmailChange : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ToEmail",
                table: "MailMessages",
                type: "character varying(320)",
                maxLength: 320,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "NewEmail",
                table: "AuthChallenges",
                type: "character varying(320)",
                maxLength: 320,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ToEmail",
                table: "MailMessages");

            migrationBuilder.DropColumn(
                name: "NewEmail",
                table: "AuthChallenges");
        }
    }
}
