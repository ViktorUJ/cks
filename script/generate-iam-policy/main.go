package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/identitystore"
	"github.com/aws/aws-sdk-go-v2/service/ssoadmin"
	"github.com/aws/aws-sdk-go-v2/service/sts"
)

type groupInfo struct {
	ID   string
	Name string
}

func parseGroups(s string) []string {
	if s == "" {
		return nil
	}
	var groups []string
	for _, g := range strings.Split(s, ";") {
		g = strings.TrimSpace(g)
		if g != "" {
			groups = append(groups, g)
		}
	}
	return groups
}

// Configuration is read from environment variables:
//   AWS_PROFILE    — AWS profile name (required)
//   AWS_REGION     — AWS region (required)
//   ALLOWED_GROUPS — semicolon-separated list of group DisplayNames;
//                    if empty, ALL groups are allowed.
//
// Example:
//   AWS_PROFILE=default AWS_REGION=us-east-1 ALLOWED_GROUPS="Developers;DevOps;Team Leads" ./generate-iam-policy

func main() {
	ctx := context.Background()

	awsProfile := os.Getenv("AWS_PROFILE")
	if awsProfile == "" {
		fatal("AWS_PROFILE is required")
	}
	awsRegion := os.Getenv("AWS_REGION")
	if awsRegion == "" {
		fatal("AWS_REGION is required")
	}
	allowedGroupNames := parseGroups(os.Getenv("ALLOWED_GROUPS"))
	if len(allowedGroupNames) == 0 {
		fatal("ALLOWED_GROUPS is required (semicolon-separated group names)")
	}

	cfg, err := config.LoadDefaultConfig(ctx,
		config.WithSharedConfigProfile(awsProfile),
		config.WithRegion(awsRegion),
	)
	if err != nil {
		fatal("Failed to load AWS config: %v", err)
	}

	// Get Identity Store ID and Account ID
	fmt.Println("Fetching SSO instance info...")
	ssoClient := ssoadmin.NewFromConfig(cfg)
	instances, err := ssoClient.ListInstances(ctx, &ssoadmin.ListInstancesInput{})
	if err != nil {
		fatal("Failed to list SSO instances: %v", err)
	}
	if len(instances.Instances) == 0 {
		fatal("No SSO instances found. Check profile and region.")
	}

	identityStoreID := *instances.Instances[0].IdentityStoreId
	var accountID string
	if instances.Instances[0].OwnerAccountId != nil {
		accountID = *instances.Instances[0].OwnerAccountId
	}
	if accountID == "" {
		stsClient := sts.NewFromConfig(cfg)
		identity, err := stsClient.GetCallerIdentity(ctx, &sts.GetCallerIdentityInput{})
		if err != nil {
			fatal("Failed to get caller identity: %v", err)
		}
		accountID = *identity.Account
	}

	fmt.Printf("Identity Store ID: %s\n", identityStoreID)
	fmt.Printf("Account ID: %s\n", accountID)

	// Fetch all groups from Identity Store
	fmt.Println("Fetching groups...")
	idClient := identitystore.NewFromConfig(cfg)
	allGroups, err := fetchAllGroups(ctx, idClient, identityStoreID)
	if err != nil {
		fatal("Failed to list groups: %v", err)
	}
	if len(allGroups) == 0 {
		fatal("No groups found in Identity Store %s", identityStoreID)
	}

	// Resolve allowed groups
	var selected []groupInfo
	nameSet := make(map[string]bool, len(allowedGroupNames))
	for _, n := range allowedGroupNames {
		nameSet[n] = true
	}
	for _, g := range allGroups {
		if nameSet[g.Name] {
			selected = append(selected, g)
			delete(nameSet, g.Name)
		}
	}
	if len(nameSet) > 0 {
		for n := range nameSet {
			fmt.Fprintf(os.Stderr, "WARNING: Group '%s' not found in Identity Store\n", n)
		}
	}

	if len(selected) == 0 {
		fatal("No matching groups found")
	}

	fmt.Println("\nGroups allowed for membership management:")
	for _, g := range selected {
		fmt.Printf("  - %s (%s)\n", g.Name, g.ID)
	}

	// Generate and write policy
	policy := buildPolicy(selected, accountID, identityStoreID)
	data, err := json.MarshalIndent(policy, "", "  ")
	if err != nil {
		fatal("Failed to marshal policy: %v", err)
	}

	outputFile := "iam-admin-policy.json"
	if err := os.WriteFile(outputFile, data, 0644); err != nil {
		fatal("Failed to write file: %v", err)
	}

	fmt.Printf("\nPolicy generated: %s\n", outputFile)
}

func fetchAllGroups(ctx context.Context, client *identitystore.Client, storeID string) ([]groupInfo, error) {
	var groups []groupInfo
	var nextToken *string

	for {
		out, err := client.ListGroups(ctx, &identitystore.ListGroupsInput{
			IdentityStoreId: &storeID,
			NextToken:       nextToken,
		})
		if err != nil {
			return nil, err
		}
		for _, g := range out.Groups {
			name := ""
			if g.DisplayName != nil {
				name = *g.DisplayName
			}
			groups = append(groups, groupInfo{ID: *g.GroupId, Name: name})
		}
		if out.NextToken == nil {
			break
		}
		nextToken = out.NextToken
	}
	return groups, nil
}

func buildPolicy(groups []groupInfo, accountID, identityStoreID string) map[string]interface{} {
	groupResources := make([]string, 0, len(groups)+3)
	for _, g := range groups {
		groupResources = append(groupResources, fmt.Sprintf("arn:aws:identitystore:::group/%s", g.ID))
	}
	groupResources = append(groupResources,
		fmt.Sprintf("arn:aws:identitystore::%s:identitystore/%s", accountID, identityStoreID),
		"arn:aws:identitystore:::user/*",
		"arn:aws:identitystore:::membership/*",
	)

	return map[string]interface{}{
		"Version": "2012-10-17",
		"Statement": []map[string]interface{}{
			{
				"Sid":    "IdentityStoreUserManagement",
				"Effect": "Allow",
				"Action": []string{
					"identitystore:CreateUser",
					"identitystore:DeleteUser",
					"identitystore:UpdateUser",
					"identitystore:DescribeUser",
					"identitystore:GetUserId",
					"identitystore:ListUsers",
				},
				"Resource": "*",
			},
			{
				"Sid":    "IdentityStoreGroupReadOnly",
				"Effect": "Allow",
				"Action": []string{
					"identitystore:DescribeGroup",
					"identitystore:GetGroupId",
					"identitystore:ListGroups",
					"identitystore:DescribeGroupMembership",
					"identitystore:GetGroupMembershipId",
					"identitystore:ListGroupMemberships",
					"identitystore:ListGroupMembershipsForMember",
					"identitystore:IsMemberInGroups",
				},
				"Resource": "*",
			},
			{
				"Sid":    "GroupMembershipLimitedToAllowedGroups",
				"Effect": "Allow",
				"Action": []string{
					"identitystore:CreateGroupMembership",
					"identitystore:DeleteGroupMembership",
				},
				"Resource": groupResources,
			},
			{
				"Sid":    "SSODirectoryReadOnly",
				"Effect": "Allow",
				"Action": []string{
					"sso-directory:SearchUsers",
					"sso-directory:SearchGroups",
					"sso-directory:DescribeUser",
					"sso-directory:DescribeGroup",
					"sso-directory:DescribeDirectory",
					"sso-directory:ListGroupsForUser",
					"sso-directory:ListMembersInGroup",
					"sso-directory:ListProvisioningTenants",
					"sso-directory:GetUserPoolInfo",
					"sso-directory:ListMfaDevicesForUser",
					"sso-directory:DisableUser",
					"sso-directory:EnableUser",
				},
				"Resource": "*",
			},
			{
				"Sid":    "SSODirectoryMfaManagement",
				"Effect": "Allow",
				"Action": []string{
					"sso-directory:CreateMfaDevice",
					"sso-directory:DeleteMfaDevice",
					"sso-directory:UpdateMfaDevice",
					"sso-directory:EnableMfaDevice",
					"sso-directory:DisableMfaDevice",
				},
				"Resource": "*",
			},
			{
				"Sid":    "SSOReadOnly",
				"Effect": "Allow",
				"Action": []string{
					"sso:Describe*",
					"sso:List*",
					"sso:Get*",
				},
				"Resource": "*",
			},
			{
				"Sid":    "OrganizationsReadOnly",
				"Effect": "Allow",
				"Action": []string{
					"organizations:DescribeOrganization",
					"organizations:DescribeAccount",
					"organizations:ListAccounts",
				},
				"Resource": "*",
			},
			{
				"Sid":    "DenyPermissionSetManagement",
				"Effect": "Deny",
				"Action": []string{
					"sso:CreatePermissionSet",
					"sso:DeletePermissionSet",
					"sso:UpdatePermissionSet",
					"sso:PutInlinePolicyToPermissionSet",
					"sso:DeleteInlinePolicyFromPermissionSet",
					"sso:AttachManagedPolicyToPermissionSet",
					"sso:DetachManagedPolicyFromPermissionSet",
					"sso:AttachCustomerManagedPolicyReferenceToPermissionSet",
					"sso:DetachCustomerManagedPolicyReferenceToPermissionSet",
					"sso:PutPermissionsBoundaryToPermissionSet",
					"sso:DeletePermissionsBoundaryFromPermissionSet",
				},
				"Resource": "*",
			},
			{
				"Sid":    "DenyAccountAssignment",
				"Effect": "Deny",
				"Action": []string{
					"sso:CreateAccountAssignment",
					"sso:DeleteAccountAssignment",
					"sso:ProvisionPermissionSet",
				},
				"Resource": "*",
			},
			{
				"Sid":    "DenyUnscopedDirectoryMembershipBypass",
				"Effect": "Deny",
				"Action": []string{
					"sso-directory:AddMemberToGroup",
					"sso-directory:RemoveMemberFromGroup",
				},
				"Resource": "*",
			},
			{
				"Sid":    "DenyGroupCreateDelete",
				"Effect": "Deny",
				"Action": []string{
					"identitystore:CreateGroup",
					"identitystore:DeleteGroup",
					"identitystore:UpdateGroup",
					"sso-directory:CreateGroup",
					"sso-directory:DeleteGroup",
					"sso-directory:UpdateGroup",
				},
				"Resource": "*",
			},
		},
	}
}

func fatal(format string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, "ERROR: "+format+"\n", args...)
	os.Exit(1)
}
