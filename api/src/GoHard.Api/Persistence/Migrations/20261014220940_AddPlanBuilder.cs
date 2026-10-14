using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace GoHard.Api.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddPlanBuilder : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Notes",
                table: "WorkoutExercises",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "TargetLoadKg",
                table: "WorkoutExercises",
                type: "numeric(9,3)",
                precision: 9,
                scale: 3,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsOngoing",
                table: "Plans",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "ScheduleJson",
                table: "Plans",
                type: "jsonb",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "TemplateId",
                table: "Plans",
                type: "character varying(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "TimeBudgetMinutes",
                table: "Plans",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "WorkoutsJson",
                table: "Plans",
                type: "jsonb",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsCustomised",
                table: "Occasions",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "SequenceIndex",
                table: "Occasions",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "WorkoutId",
                table: "Occasions",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "CustomExercises",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    Category = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    Equipment = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    IsTimed = table.Column<bool>(type: "boolean", nullable: false),
                    IsArchived = table.Column<bool>(type: "boolean", nullable: false),
                    Revision = table.Column<int>(type: "integer", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CustomExercises", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CustomExercises_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Occasions_PlanId_SequenceIndex",
                table: "Occasions",
                columns: new[] { "PlanId", "SequenceIndex" },
                unique: true,
                filter: "\"SequenceIndex\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_CustomExercises_UserId",
                table: "CustomExercises",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CustomExercises");

            migrationBuilder.DropIndex(
                name: "IX_Occasions_PlanId_SequenceIndex",
                table: "Occasions");

            migrationBuilder.DropColumn(
                name: "Notes",
                table: "WorkoutExercises");

            migrationBuilder.DropColumn(
                name: "TargetLoadKg",
                table: "WorkoutExercises");

            migrationBuilder.DropColumn(
                name: "IsOngoing",
                table: "Plans");

            migrationBuilder.DropColumn(
                name: "ScheduleJson",
                table: "Plans");

            migrationBuilder.DropColumn(
                name: "TemplateId",
                table: "Plans");

            migrationBuilder.DropColumn(
                name: "TimeBudgetMinutes",
                table: "Plans");

            migrationBuilder.DropColumn(
                name: "WorkoutsJson",
                table: "Plans");

            migrationBuilder.DropColumn(
                name: "IsCustomised",
                table: "Occasions");

            migrationBuilder.DropColumn(
                name: "SequenceIndex",
                table: "Occasions");

            migrationBuilder.DropColumn(
                name: "WorkoutId",
                table: "Occasions");
        }
    }
}
