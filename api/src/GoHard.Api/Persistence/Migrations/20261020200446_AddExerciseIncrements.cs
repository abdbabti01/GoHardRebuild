using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GoHard.Api.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddExerciseIncrements : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ExerciseIncrements",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ExerciseKey = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    IncrementKg = table.Column<decimal>(type: "numeric(9,5)", precision: 9, scale: 5, nullable: true),
                    Revision = table.Column<int>(type: "integer", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ExerciseIncrements", x => new { x.UserId, x.ExerciseKey });
                    table.ForeignKey(
                        name: "FK_ExerciseIncrements_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ExerciseIncrements");
        }
    }
}
