CREATE TABLE "access_policy_version" (
	"id" integer PRIMARY KEY DEFAULT 1 NOT NULL,
	"version" integer DEFAULT 1 NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "guardian_student" (
	"guardian_id" text NOT NULL,
	"student_id" text NOT NULL,
	"relationship" text,
	"is_primary" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "guardian_student_guardian_id_student_id_pk" PRIMARY KEY("guardian_id","student_id")
);
--> statement-breakpoint
CREATE TABLE "role_permission_override" (
	"role" text NOT NULL,
	"permission" text NOT NULL,
	"granted" boolean NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_by" text,
	CONSTRAINT "role_permission_override_role_permission_pk" PRIMARY KEY("role","permission")
);
--> statement-breakpoint
CREATE TABLE "role_screen_access" (
	"role" text NOT NULL,
	"screen_id" text NOT NULL,
	"allowed" boolean NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_by" text,
	CONSTRAINT "role_screen_access_role_screen_id_pk" PRIMARY KEY("role","screen_id")
);
--> statement-breakpoint
CREATE TABLE "staff_assignment" (
	"user_id" text NOT NULL,
	"class_id" text NOT NULL,
	"is_class_teacher" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "staff_assignment_user_id_class_id_pk" PRIMARY KEY("user_id","class_id")
);
--> statement-breakpoint
CREATE TABLE "user_screen_override" (
	"user_id" text NOT NULL,
	"screen_id" text NOT NULL,
	"allowed" boolean NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "user_screen_override_user_id_screen_id_pk" PRIMARY KEY("user_id","screen_id")
);
--> statement-breakpoint
ALTER TABLE "guardian_student" ADD CONSTRAINT "guardian_student_guardian_id_user_id_fk" FOREIGN KEY ("guardian_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "role_permission_override" ADD CONSTRAINT "role_permission_override_updated_by_user_id_fk" FOREIGN KEY ("updated_by") REFERENCES "public"."user"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "role_screen_access" ADD CONSTRAINT "role_screen_access_updated_by_user_id_fk" FOREIGN KEY ("updated_by") REFERENCES "public"."user"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_assignment" ADD CONSTRAINT "staff_assignment_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_screen_override" ADD CONSTRAINT "user_screen_override_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "guardian_student_student_idx" ON "guardian_student" USING btree ("student_id");--> statement-breakpoint
CREATE UNIQUE INDEX "staff_assignment_class_teacher_idx" ON "staff_assignment" USING btree ("class_id") WHERE "staff_assignment"."is_class_teacher";--> statement-breakpoint
CREATE INDEX "user_screen_override_user_idx" ON "user_screen_override" USING btree ("user_id");