//go:build wireinject
// +build wireinject

//go:generate go run github.com/google/wire/cmd/wire

// This file defines the dependency injection ProviderSet for the data layer and contains no business logic.
// The build tag `wireinject` excludes this source from normal `go build` and final binaries.
// Run `go generate ./...` or `go run github.com/google/wire/cmd/wire` to regenerate the Wire output (e.g. `wire_gen.go`), which will be included in final builds.
// Keep provider constructors here only; avoid init-time side effects or runtime logic in this file.

package providers

import (
	"github.com/google/wire"

	"go-wind-cms/app/core/service/internal/data"
	"go-wind-cms/app/core/service/internal/data/client"
	"go-wind-cms/pkg/authorizer"
)

// ProviderSet is the Wire provider set for data layer.
var ProviderSet = wire.NewSet(
	client.NewRedisClient,
	client.NewEntClient,
	client.NewDiscovery,

	authorizer.NewAuthorizer,

	data.NewAuthenticatorConfig,
	data.NewAuthenticator,
	data.NewUserTokenCache,

	data.NewPasswordCrypto,

	data.NewDictTypeRepo,
	data.NewDictEntryRepo,
	data.NewDictEntryI18nRepo,
	data.NewLanguageRepo,

	data.NewTaskRepo,
	data.NewLoginPolicyRepo,

	data.NewBoardRepo,
	data.NewColumnRepo,
	data.NewCardRepo,

	data.NewOrgUnitRepo,
	data.NewPositionRepo,
	data.NewTenantRepo,

	data.NewUserRepo,
	data.NewUserCredentialRepo,
	data.NewUserOrgUnitRepo,
	data.NewUserPositionRepo,
	data.NewUserRoleRepo,

	data.NewRoleRepo,
	data.NewRoleMetadataRepo,
	data.NewRolePermissionRepo,

	data.NewMembershipRepo,
	data.NewMembershipOrgUnitRepo,
	data.NewMembershipPositionRepo,
	data.NewMembershipRoleRepo,

	data.NewApiRepo,
	data.NewMenuRepo,

	data.NewPermissionRepo,
	data.NewPermissionGroupRepo,
	data.NewPermissionApiRepo,
	data.NewPermissionMenuRepo,
	data.NewPermissionAuditLogRepo,
	data.NewPolicyEvaluationLogRepo,

	data.NewLoginAuditLogRepo,
	data.NewApiAuditLogRepo,
	data.NewOperationAuditLogRepo,
	data.NewDataAccessAuditLogRepo,

	data.NewInternalMessageRepo,
	data.NewInternalMessageCategoryRepo,
	data.NewInternalMessageRecipientRepo,

)
