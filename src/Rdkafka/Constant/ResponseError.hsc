#include <librdkafka/rdkafka.h>

{-# language BangPatterns #-}
{-# language DeriveAnyClass #-}
{-# language DerivingStrategies #-}
{-# language GeneralizedNewtypeDeriving #-}
{-# language MagicHash #-}
{-# language PatternSynonyms #-}

module Rdkafka.Constant.ResponseError
  ( ResponseError(..)
  , encodeAddr##
  , pattern Begin
  , pattern BadMsg
  , pattern BadCompression
  , pattern Destroy
  , pattern Fail
  , pattern Transport
  , pattern CritSysResource
  , pattern Resolve
  , pattern MsgTimedOut
  , pattern PartitionEof
  , pattern UnknownPartition
  , pattern Fs
  , pattern UnknownTopic
  , pattern AllBrokersDown
  , pattern InvalidArg
  , pattern TimedOut
  , pattern QueueFull
  , pattern IsrInsuff
  , pattern NodeUpdate
  , pattern Ssl
  , pattern WaitCoord
  , pattern UnknownGroup
  , pattern InProgress
  , pattern PrevInProgress
  , pattern ExistingSubscription
  , pattern AssignPartitions
  , pattern RevokePartitions
  , pattern Conflict
  , pattern State
  , pattern UnknownProtocol
  , pattern NotImplemented
  , pattern Authentication
  , pattern NoOffset
  , pattern Outdated
  , pattern TimedOutQueue
  , pattern UnsupportedFeature
  , pattern WaitCache
  , pattern Intr
  , pattern KeySerialization
  , pattern ValueSerialization
  , pattern KeyDeserialization
  , pattern ValueDeserialization
  , pattern Partial
  , pattern ReadOnly
  , pattern Noent
  , pattern Underflow
  , pattern InvalidType
  , pattern Retry
  , pattern PurgeQueue
  , pattern PurgeInflight
  , pattern Fatal
  , pattern Inconsistent
  , pattern GaplessGuarantee
  , pattern MaxPollExceeded
  , pattern UnknownBroker
  , pattern NotConfigured
  , pattern Fenced
  , pattern Application
  , pattern End
  , pattern Unknown
  , pattern NoError
  , pattern OffsetOutOfRange
  , pattern InvalidMsg
  , pattern UnknownTopicOrPart
  , pattern InvalidMsgSize
  , pattern LeaderNotAvailable
  , pattern NotLeaderForPartition
  , pattern RequestTimedOut
  , pattern BrokerNotAvailable
  , pattern ReplicaNotAvailable
  , pattern MsgSizeTooLarge
  , pattern StaleCtrlEpoch
  , pattern OffsetMetadataTooLarge
  , pattern NetworkException
  , pattern CoordinatorLoadInProgress
  , pattern CoordinatorNotAvailable
  , pattern NotCoordinator
  , pattern TopicException
  , pattern RecordListTooLarge
  , pattern NotEnoughReplicas
  , pattern NotEnoughReplicasAfterAppend
  , pattern InvalidRequiredAcks
  , pattern IllegalGeneration
  , pattern InconsistentGroupProtocol
  , pattern InvalidGroupId
  , pattern UnknownMemberId
  , pattern InvalidSessionTimeout
  , pattern RebalanceInProgress
  , pattern InvalidCommitOffsetSize
  , pattern TopicAuthorizationFailed
  , pattern GroupAuthorizationFailed
  , pattern ClusterAuthorizationFailed
  , pattern InvalidTimestamp
  , pattern UnsupportedSaslMechanism
  , pattern IllegalSaslState
  , pattern UnsupportedVersion
  , pattern TopicAlreadyExists
  , pattern InvalidPartitions
  , pattern InvalidReplicationFactor
  , pattern InvalidReplicaAssignment
  , pattern InvalidConfig
  , pattern NotController
  , pattern InvalidRequest
  , pattern UnsupportedForMessageFormat
  , pattern PolicyViolation
  , pattern OutOfOrderSequenceNumber
  , pattern DuplicateSequenceNumber
  , pattern InvalidProducerEpoch
  , pattern InvalidTxnState
  , pattern InvalidProducerIdMapping
  , pattern InvalidTransactionTimeout
  , pattern ConcurrentTransactions
  , pattern TransactionCoordinatorFenced
  , pattern TransactionalIdAuthorizationFailed
  , pattern SecurityDisabled
  , pattern OperationNotAttempted
  , pattern KafkaStorageError
  , pattern LogDirNotFound
  , pattern SaslAuthenticationFailed
  , pattern UnknownProducerId
  , pattern ReassignmentInProgress
  , pattern DelegationTokenAuthDisabled
  , pattern DelegationTokenNotFound
  , pattern DelegationTokenOwnerMismatch
  , pattern DelegationTokenRequestNotAllowed
  , pattern DelegationTokenAuthorizationFailed
  , pattern DelegationTokenExpired
  , pattern InvalidPrincipalType
  , pattern NonEmptyGroup
  , pattern GroupIdNotFound
  , pattern FetchSessionIdNotFound
  , pattern InvalidFetchSessionEpoch
  , pattern ListenerNotFound
  , pattern TopicDeletionDisabled
  , pattern FencedLeaderEpoch
  , pattern UnknownLeaderEpoch
  , pattern UnsupportedCompressionType
  , pattern StaleBrokerEpoch
  , pattern OffsetNotAvailable
  , pattern MemberIdRequired
  , pattern PreferredLeaderNotAvailable
  , pattern GroupMaxSizeReached
  , pattern FencedInstanceId
  ) where

import Control.Exception (Exception)
import Foreign.C.Types (CInt)
import Foreign.Storable (Storable)
import GHC.Exts (Addr##)

-- | Corresponds to @rd_kafka_resp_err_t@.
newtype ResponseError = ResponseError CInt
  deriving newtype (Eq,Storable)
  deriving anyclass (Exception)

-- | Encode response error as primitive string literal.
encodeAddr## :: ResponseError -> Addr##
encodeAddr## e = case e of
  Begin -> "Begin"##
  BadMsg -> "BadMsg"##
  BadCompression -> "BadCompression"##
  Destroy -> "Destroy"##
  Fail -> "Fail"##
  Transport -> "Transport"##
  CritSysResource -> "CritSysResource"##
  Resolve -> "Resolve"##
  MsgTimedOut -> "MsgTimedOut"##
  PartitionEof -> "PartitionEof"##
  UnknownPartition -> "UnknownPartition"##
  Fs -> "Fs"##
  UnknownTopic -> "UnknownTopic"##
  AllBrokersDown -> "AllBrokersDown"##
  InvalidArg -> "InvalidArg"##
  TimedOut -> "TimedOut"##
  QueueFull -> "QueueFull"##
  IsrInsuff -> "IsrInsuff"##
  NodeUpdate -> "NodeUpdate"##
  Ssl -> "Ssl"##
  WaitCoord -> "WaitCoord"##
  UnknownGroup -> "UnknownGroup"##
  InProgress -> "InProgress"##
  PrevInProgress -> "PrevInProgress"##
  ExistingSubscription -> "ExistingSubscription"##
  AssignPartitions -> "AssignPartitions"##
  RevokePartitions -> "RevokePartitions"##
  Conflict -> "Conflict"##
  State -> "State"##
  UnknownProtocol -> "UnknownProtocol"##
  NotImplemented -> "NotImplemented"##
  Authentication -> "Authentication"##
  NoOffset -> "NoOffset"##
  Outdated -> "Outdated"##
  TimedOutQueue -> "TimedOutQueue"##
  UnsupportedFeature -> "UnsupportedFeature"##
  WaitCache -> "WaitCache"##
  Intr -> "Intr"##
  KeySerialization -> "KeySerialization"##
  ValueSerialization -> "ValueSerialization"##
  KeyDeserialization -> "KeyDeserialization"##
  ValueDeserialization -> "ValueDeserialization"##
  Partial -> "Partial"##
  ReadOnly -> "ReadOnly"##
  Noent -> "Noent"##
  Underflow -> "Underflow"##
  InvalidType -> "InvalidType"##
  Retry -> "Retry"##
  PurgeQueue -> "PurgeQueue"##
  PurgeInflight -> "PurgeInflight"##
  Fatal -> "Fatal"##
  Inconsistent -> "Inconsistent"##
  GaplessGuarantee -> "GaplessGuarantee"##
  MaxPollExceeded -> "MaxPollExceeded"##
  UnknownBroker -> "UnknownBroker"##
  NotConfigured -> "NotConfigured"##
  Fenced -> "Fenced"##
  Application -> "Application"##
  End -> "End"##
  Unknown -> "Unknown"##
  NoError -> "NoError"##
  OffsetOutOfRange -> "OffsetOutOfRange"##
  InvalidMsg -> "InvalidMsg"##
  UnknownTopicOrPart -> "UnknownTopicOrPart"##
  InvalidMsgSize -> "InvalidMsgSize"##
  LeaderNotAvailable -> "LeaderNotAvailable"##
  NotLeaderForPartition -> "NotLeaderForPartition"##
  RequestTimedOut -> "RequestTimedOut"##
  BrokerNotAvailable -> "BrokerNotAvailable"##
  ReplicaNotAvailable -> "ReplicaNotAvailable"##
  MsgSizeTooLarge -> "MsgSizeTooLarge"##
  StaleCtrlEpoch -> "StaleCtrlEpoch"##
  OffsetMetadataTooLarge -> "OffsetMetadataTooLarge"##
  NetworkException -> "NetworkException"##
  CoordinatorLoadInProgress -> "CoordinatorLoadInProgress"##
  CoordinatorNotAvailable -> "CoordinatorNotAvailable"##
  NotCoordinator -> "NotCoordinator"##
  TopicException -> "TopicException"##
  RecordListTooLarge -> "RecordListTooLarge"##
  NotEnoughReplicas -> "NotEnoughReplicas"##
  NotEnoughReplicasAfterAppend -> "NotEnoughReplicasAfterAppend"##
  InvalidRequiredAcks -> "InvalidRequiredAcks"##
  IllegalGeneration -> "IllegalGeneration"##
  InconsistentGroupProtocol -> "InconsistentGroupProtocol"##
  InvalidGroupId -> "InvalidGroupId"##
  UnknownMemberId -> "UnknownMemberId"##
  InvalidSessionTimeout -> "InvalidSessionTimeout"##
  RebalanceInProgress -> "RebalanceInProgress"##
  InvalidCommitOffsetSize -> "InvalidCommitOffsetSize"##
  TopicAuthorizationFailed -> "TopicAuthorizationFailed"##
  GroupAuthorizationFailed -> "GroupAuthorizationFailed"##
  ClusterAuthorizationFailed -> "ClusterAuthorizationFailed"##
  InvalidTimestamp -> "InvalidTimestamp"##
  UnsupportedSaslMechanism -> "UnsupportedSaslMechanism"##
  IllegalSaslState -> "IllegalSaslState"##
  UnsupportedVersion -> "UnsupportedVersion"##
  TopicAlreadyExists -> "TopicAlreadyExists"##
  InvalidPartitions -> "InvalidPartitions"##
  InvalidReplicationFactor -> "InvalidReplicationFactor"##
  InvalidReplicaAssignment -> "InvalidReplicaAssignment"##
  InvalidConfig -> "InvalidConfig"##
  NotController -> "NotController"##
  InvalidRequest -> "InvalidRequest"##
  UnsupportedForMessageFormat -> "UnsupportedForMessageFormat"##
  PolicyViolation -> "PolicyViolation"##
  OutOfOrderSequenceNumber -> "OutOfOrderSequenceNumber"##
  DuplicateSequenceNumber -> "DuplicateSequenceNumber"##
  InvalidProducerEpoch -> "InvalidProducerEpoch"##
  InvalidTxnState -> "InvalidTxnState"##
  InvalidProducerIdMapping -> "InvalidProducerIdMapping"##
  InvalidTransactionTimeout -> "InvalidTransactionTimeout"##
  ConcurrentTransactions -> "ConcurrentTransactions"##
  TransactionCoordinatorFenced -> "TransactionCoordinatorFenced"##
  TransactionalIdAuthorizationFailed -> "TransactionalIdAuthorizationFailed"##
  SecurityDisabled -> "SecurityDisabled"##
  OperationNotAttempted -> "OperationNotAttempted"##
  KafkaStorageError -> "KafkaStorageError"##
  LogDirNotFound -> "LogDirNotFound"##
  SaslAuthenticationFailed -> "SaslAuthenticationFailed"##
  UnknownProducerId -> "UnknownProducerId"##
  ReassignmentInProgress -> "ReassignmentInProgress"##
  DelegationTokenAuthDisabled -> "DelegationTokenAuthDisabled"##
  DelegationTokenNotFound -> "DelegationTokenNotFound"##
  DelegationTokenOwnerMismatch -> "DelegationTokenOwnerMismatch"##
  DelegationTokenRequestNotAllowed -> "DelegationTokenRequestNotAllowed"##
  DelegationTokenAuthorizationFailed -> "DelegationTokenAuthorizationFailed"##
  DelegationTokenExpired -> "DelegationTokenExpired"##
  InvalidPrincipalType -> "InvalidPrincipalType"##
  NonEmptyGroup -> "NonEmptyGroup"##
  GroupIdNotFound -> "GroupIdNotFound"##
  FetchSessionIdNotFound -> "FetchSessionIdNotFound"##
  InvalidFetchSessionEpoch -> "InvalidFetchSessionEpoch"##
  ListenerNotFound -> "ListenerNotFound"##
  TopicDeletionDisabled -> "TopicDeletionDisabled"##
  FencedLeaderEpoch -> "FencedLeaderEpoch"##
  UnknownLeaderEpoch -> "UnknownLeaderEpoch"##
  UnsupportedCompressionType -> "UnsupportedCompressionType"##
  StaleBrokerEpoch -> "StaleBrokerEpoch"##
  OffsetNotAvailable -> "OffsetNotAvailable"##
  MemberIdRequired -> "MemberIdRequired"##
  PreferredLeaderNotAvailable -> "PreferredLeaderNotAvailable"##
  GroupMaxSizeReached -> "GroupMaxSizeReached"##
  FencedInstanceId -> "FencedInstanceId"##
  _ -> "Unknown"##

instance Show ResponseError where
  showsPrec !d !e s = case e of
    Begin -> "Begin " ++ s
    BadMsg -> "BadMsg " ++ s
    BadCompression -> "BadCompression " ++ s
    Destroy -> "Destroy " ++ s
    Fail -> "Fail " ++ s
    Transport -> "Transport " ++ s
    CritSysResource -> "CritSysResource " ++ s
    Resolve -> "Resolve " ++ s
    MsgTimedOut -> "MsgTimedOut " ++ s
    PartitionEof -> "PartitionEof " ++ s
    UnknownPartition -> "UnknownPartition " ++ s
    Fs -> "Fs " ++ s
    UnknownTopic -> "UnknownTopic " ++ s
    AllBrokersDown -> "AllBrokersDown " ++ s
    InvalidArg -> "InvalidArg " ++ s
    TimedOut -> "TimedOut " ++ s
    QueueFull -> "QueueFull " ++ s
    IsrInsuff -> "IsrInsuff " ++ s
    NodeUpdate -> "NodeUpdate " ++ s
    Ssl -> "Ssl " ++ s
    WaitCoord -> "WaitCoord " ++ s
    UnknownGroup -> "UnknownGroup " ++ s
    InProgress -> "InProgress " ++ s
    PrevInProgress -> "PrevInProgress " ++ s
    ExistingSubscription -> "ExistingSubscription " ++ s
    AssignPartitions -> "AssignPartitions " ++ s
    RevokePartitions -> "RevokePartitions " ++ s
    Conflict -> "Conflict " ++ s
    State -> "State " ++ s
    UnknownProtocol -> "UnknownProtocol " ++ s
    NotImplemented -> "NotImplemented " ++ s
    Authentication -> "Authentication " ++ s
    NoOffset -> "NoOffset " ++ s
    Outdated -> "Outdated " ++ s
    TimedOutQueue -> "TimedOutQueue " ++ s
    UnsupportedFeature -> "UnsupportedFeature " ++ s
    WaitCache -> "WaitCache " ++ s
    Intr -> "Intr " ++ s
    KeySerialization -> "KeySerialization " ++ s
    ValueSerialization -> "ValueSerialization " ++ s
    KeyDeserialization -> "KeyDeserialization " ++ s
    ValueDeserialization -> "ValueDeserialization " ++ s
    Partial -> "Partial " ++ s
    ReadOnly -> "ReadOnly " ++ s
    Noent -> "Noent " ++ s
    Underflow -> "Underflow " ++ s
    InvalidType -> "InvalidType " ++ s
    Retry -> "Retry " ++ s
    PurgeQueue -> "PurgeQueue " ++ s
    PurgeInflight -> "PurgeInflight " ++ s
    Fatal -> "Fatal " ++ s
    Inconsistent -> "Inconsistent " ++ s
    GaplessGuarantee -> "GaplessGuarantee " ++ s
    MaxPollExceeded -> "MaxPollExceeded " ++ s
    UnknownBroker -> "UnknownBroker " ++ s
    NotConfigured -> "NotConfigured " ++ s
    Fenced -> "Fenced " ++ s
    Application -> "Application " ++ s
    End -> "End " ++ s
    Unknown -> "Unknown " ++ s
    NoError -> "NoError " ++ s
    OffsetOutOfRange -> "OffsetOutOfRange " ++ s
    InvalidMsg -> "InvalidMsg " ++ s
    UnknownTopicOrPart -> "UnknownTopicOrPart " ++ s
    InvalidMsgSize -> "InvalidMsgSize " ++ s
    LeaderNotAvailable -> "LeaderNotAvailable " ++ s
    NotLeaderForPartition -> "NotLeaderForPartition " ++ s
    RequestTimedOut -> "RequestTimedOut " ++ s
    BrokerNotAvailable -> "BrokerNotAvailable " ++ s
    ReplicaNotAvailable -> "ReplicaNotAvailable " ++ s
    MsgSizeTooLarge -> "MsgSizeTooLarge " ++ s
    StaleCtrlEpoch -> "StaleCtrlEpoch " ++ s
    OffsetMetadataTooLarge -> "OffsetMetadataTooLarge " ++ s
    NetworkException -> "NetworkException " ++ s
    CoordinatorLoadInProgress -> "CoordinatorLoadInProgress " ++ s
    CoordinatorNotAvailable -> "CoordinatorNotAvailable " ++ s
    NotCoordinator -> "NotCoordinator " ++ s
    TopicException -> "TopicException " ++ s
    RecordListTooLarge -> "RecordListTooLarge " ++ s
    NotEnoughReplicas -> "NotEnoughReplicas " ++ s
    NotEnoughReplicasAfterAppend -> "NotEnoughReplicasAfterAppend " ++ s
    InvalidRequiredAcks -> "InvalidRequiredAcks " ++ s
    IllegalGeneration -> "IllegalGeneration " ++ s
    InconsistentGroupProtocol -> "InconsistentGroupProtocol " ++ s
    InvalidGroupId -> "InvalidGroupId " ++ s
    UnknownMemberId -> "UnknownMemberId " ++ s
    InvalidSessionTimeout -> "InvalidSessionTimeout " ++ s
    RebalanceInProgress -> "RebalanceInProgress " ++ s
    InvalidCommitOffsetSize -> "InvalidCommitOffsetSize " ++ s
    TopicAuthorizationFailed -> "TopicAuthorizationFailed " ++ s
    GroupAuthorizationFailed -> "GroupAuthorizationFailed " ++ s
    ClusterAuthorizationFailed -> "ClusterAuthorizationFailed " ++ s
    InvalidTimestamp -> "InvalidTimestamp " ++ s
    UnsupportedSaslMechanism -> "UnsupportedSaslMechanism " ++ s
    IllegalSaslState -> "IllegalSaslState " ++ s
    UnsupportedVersion -> "UnsupportedVersion " ++ s
    TopicAlreadyExists -> "TopicAlreadyExists " ++ s
    InvalidPartitions -> "InvalidPartitions " ++ s
    InvalidReplicationFactor -> "InvalidReplicationFactor " ++ s
    InvalidReplicaAssignment -> "InvalidReplicaAssignment " ++ s
    InvalidConfig -> "InvalidConfig " ++ s
    NotController -> "NotController " ++ s
    InvalidRequest -> "InvalidRequest " ++ s
    UnsupportedForMessageFormat -> "UnsupportedForMessageFormat " ++ s
    PolicyViolation -> "PolicyViolation " ++ s
    OutOfOrderSequenceNumber -> "OutOfOrderSequenceNumber " ++ s
    DuplicateSequenceNumber -> "DuplicateSequenceNumber " ++ s
    InvalidProducerEpoch -> "InvalidProducerEpoch " ++ s
    InvalidTxnState -> "InvalidTxnState " ++ s
    InvalidProducerIdMapping -> "InvalidProducerIdMapping " ++ s
    InvalidTransactionTimeout -> "InvalidTransactionTimeout " ++ s
    ConcurrentTransactions -> "ConcurrentTransactions " ++ s
    TransactionCoordinatorFenced -> "TransactionCoordinatorFenced " ++ s
    TransactionalIdAuthorizationFailed -> "TransactionalIdAuthorizationFailed " ++ s
    SecurityDisabled -> "SecurityDisabled " ++ s
    OperationNotAttempted -> "OperationNotAttempted " ++ s
    KafkaStorageError -> "KafkaStorageError " ++ s
    LogDirNotFound -> "LogDirNotFound " ++ s
    SaslAuthenticationFailed -> "SaslAuthenticationFailed " ++ s
    UnknownProducerId -> "UnknownProducerId " ++ s
    ReassignmentInProgress -> "ReassignmentInProgress " ++ s
    DelegationTokenAuthDisabled -> "DelegationTokenAuthDisabled " ++ s
    DelegationTokenNotFound -> "DelegationTokenNotFound " ++ s
    DelegationTokenOwnerMismatch -> "DelegationTokenOwnerMismatch " ++ s
    DelegationTokenRequestNotAllowed -> "DelegationTokenRequestNotAllowed " ++ s
    DelegationTokenAuthorizationFailed -> "DelegationTokenAuthorizationFailed " ++ s
    DelegationTokenExpired -> "DelegationTokenExpired " ++ s
    InvalidPrincipalType -> "InvalidPrincipalType " ++ s
    NonEmptyGroup -> "NonEmptyGroup " ++ s
    GroupIdNotFound -> "GroupIdNotFound " ++ s
    FetchSessionIdNotFound -> "FetchSessionIdNotFound " ++ s
    InvalidFetchSessionEpoch -> "InvalidFetchSessionEpoch " ++ s
    ListenerNotFound -> "ListenerNotFound " ++ s
    TopicDeletionDisabled -> "TopicDeletionDisabled " ++ s
    FencedLeaderEpoch -> "FencedLeaderEpoch " ++ s
    UnknownLeaderEpoch -> "UnknownLeaderEpoch " ++ s
    UnsupportedCompressionType -> "UnsupportedCompressionType " ++ s
    StaleBrokerEpoch -> "StaleBrokerEpoch " ++ s
    OffsetNotAvailable -> "OffsetNotAvailable " ++ s
    MemberIdRequired -> "MemberIdRequired " ++ s
    PreferredLeaderNotAvailable -> "PreferredLeaderNotAvailable " ++ s
    GroupMaxSizeReached -> "GroupMaxSizeReached " ++ s
    FencedInstanceId -> "FencedInstanceId " ++ s
    ResponseError e -> showParen (d > 10) (showString "ResponseError " . showsPrec 11 e) s

pattern Begin :: ResponseError
pattern Begin = ResponseError ( #{const RD_KAFKA_RESP_ERR__BEGIN} )
pattern BadMsg :: ResponseError
pattern BadMsg = ResponseError ( #{const RD_KAFKA_RESP_ERR__BAD_MSG} )
pattern BadCompression :: ResponseError
pattern BadCompression = ResponseError ( #{const RD_KAFKA_RESP_ERR__BAD_COMPRESSION} )
pattern Destroy :: ResponseError
pattern Destroy = ResponseError ( #{const RD_KAFKA_RESP_ERR__DESTROY} )
pattern Fail :: ResponseError
pattern Fail = ResponseError ( #{const RD_KAFKA_RESP_ERR__FAIL} )
pattern Transport :: ResponseError
pattern Transport = ResponseError ( #{const RD_KAFKA_RESP_ERR__TRANSPORT} )
pattern CritSysResource :: ResponseError
pattern CritSysResource = ResponseError ( #{const RD_KAFKA_RESP_ERR__CRIT_SYS_RESOURCE} )
pattern Resolve :: ResponseError
pattern Resolve = ResponseError ( #{const RD_KAFKA_RESP_ERR__RESOLVE} )
pattern MsgTimedOut :: ResponseError
pattern MsgTimedOut = ResponseError ( #{const RD_KAFKA_RESP_ERR__MSG_TIMED_OUT} )
pattern PartitionEof :: ResponseError
pattern PartitionEof = ResponseError ( #{const RD_KAFKA_RESP_ERR__PARTITION_EOF} )
pattern UnknownPartition :: ResponseError
pattern UnknownPartition = ResponseError ( #{const RD_KAFKA_RESP_ERR__UNKNOWN_PARTITION} )
pattern Fs :: ResponseError
pattern Fs = ResponseError ( #{const RD_KAFKA_RESP_ERR__FS} )
pattern UnknownTopic :: ResponseError
pattern UnknownTopic = ResponseError ( #{const RD_KAFKA_RESP_ERR__UNKNOWN_TOPIC} )
pattern AllBrokersDown :: ResponseError
pattern AllBrokersDown = ResponseError ( #{const RD_KAFKA_RESP_ERR__ALL_BROKERS_DOWN} )
pattern InvalidArg :: ResponseError
pattern InvalidArg = ResponseError ( #{const RD_KAFKA_RESP_ERR__INVALID_ARG} )
pattern TimedOut :: ResponseError
pattern TimedOut = ResponseError ( #{const RD_KAFKA_RESP_ERR__TIMED_OUT} )
pattern QueueFull :: ResponseError
pattern QueueFull = ResponseError ( #{const RD_KAFKA_RESP_ERR__QUEUE_FULL} )
pattern IsrInsuff :: ResponseError
pattern IsrInsuff = ResponseError ( #{const RD_KAFKA_RESP_ERR__ISR_INSUFF} )
pattern NodeUpdate :: ResponseError
pattern NodeUpdate = ResponseError ( #{const RD_KAFKA_RESP_ERR__NODE_UPDATE} )
pattern Ssl :: ResponseError
pattern Ssl = ResponseError ( #{const RD_KAFKA_RESP_ERR__SSL} )
pattern WaitCoord :: ResponseError
pattern WaitCoord = ResponseError ( #{const RD_KAFKA_RESP_ERR__WAIT_COORD} )
pattern UnknownGroup :: ResponseError
pattern UnknownGroup = ResponseError ( #{const RD_KAFKA_RESP_ERR__UNKNOWN_GROUP} )
pattern InProgress :: ResponseError
pattern InProgress = ResponseError ( #{const RD_KAFKA_RESP_ERR__IN_PROGRESS} )
pattern PrevInProgress :: ResponseError
pattern PrevInProgress = ResponseError ( #{const RD_KAFKA_RESP_ERR__PREV_IN_PROGRESS} )
pattern ExistingSubscription :: ResponseError
pattern ExistingSubscription = ResponseError ( #{const RD_KAFKA_RESP_ERR__EXISTING_SUBSCRIPTION} )
pattern AssignPartitions :: ResponseError
pattern AssignPartitions = ResponseError ( #{const RD_KAFKA_RESP_ERR__ASSIGN_PARTITIONS} )
pattern RevokePartitions :: ResponseError
pattern RevokePartitions = ResponseError ( #{const RD_KAFKA_RESP_ERR__REVOKE_PARTITIONS} )
pattern Conflict :: ResponseError
pattern Conflict = ResponseError ( #{const RD_KAFKA_RESP_ERR__CONFLICT} )
pattern State :: ResponseError
pattern State = ResponseError ( #{const RD_KAFKA_RESP_ERR__STATE} )
pattern UnknownProtocol :: ResponseError
pattern UnknownProtocol = ResponseError ( #{const RD_KAFKA_RESP_ERR__UNKNOWN_PROTOCOL} )
pattern NotImplemented :: ResponseError
pattern NotImplemented = ResponseError ( #{const RD_KAFKA_RESP_ERR__NOT_IMPLEMENTED} )
pattern Authentication :: ResponseError
pattern Authentication = ResponseError ( #{const RD_KAFKA_RESP_ERR__AUTHENTICATION} )
pattern NoOffset :: ResponseError
pattern NoOffset = ResponseError ( #{const RD_KAFKA_RESP_ERR__NO_OFFSET} )
pattern Outdated :: ResponseError
pattern Outdated = ResponseError ( #{const RD_KAFKA_RESP_ERR__OUTDATED} )
pattern TimedOutQueue :: ResponseError
pattern TimedOutQueue = ResponseError ( #{const RD_KAFKA_RESP_ERR__TIMED_OUT_QUEUE} )
pattern UnsupportedFeature :: ResponseError
pattern UnsupportedFeature = ResponseError ( #{const RD_KAFKA_RESP_ERR__UNSUPPORTED_FEATURE} )
pattern WaitCache :: ResponseError
pattern WaitCache = ResponseError ( #{const RD_KAFKA_RESP_ERR__WAIT_CACHE} )
pattern Intr :: ResponseError
pattern Intr = ResponseError ( #{const RD_KAFKA_RESP_ERR__INTR} )
pattern KeySerialization :: ResponseError
pattern KeySerialization = ResponseError ( #{const RD_KAFKA_RESP_ERR__KEY_SERIALIZATION} )
pattern ValueSerialization :: ResponseError
pattern ValueSerialization = ResponseError ( #{const RD_KAFKA_RESP_ERR__VALUE_SERIALIZATION} )
pattern KeyDeserialization :: ResponseError
pattern KeyDeserialization = ResponseError ( #{const RD_KAFKA_RESP_ERR__KEY_DESERIALIZATION} )
pattern ValueDeserialization :: ResponseError
pattern ValueDeserialization = ResponseError ( #{const RD_KAFKA_RESP_ERR__VALUE_DESERIALIZATION} )
pattern Partial :: ResponseError
pattern Partial = ResponseError ( #{const RD_KAFKA_RESP_ERR__PARTIAL} )
pattern ReadOnly :: ResponseError
pattern ReadOnly = ResponseError ( #{const RD_KAFKA_RESP_ERR__READ_ONLY} )
pattern Noent :: ResponseError
pattern Noent = ResponseError ( #{const RD_KAFKA_RESP_ERR__NOENT} )
pattern Underflow :: ResponseError
pattern Underflow = ResponseError ( #{const RD_KAFKA_RESP_ERR__UNDERFLOW} )
pattern InvalidType :: ResponseError
pattern InvalidType = ResponseError ( #{const RD_KAFKA_RESP_ERR__INVALID_TYPE} )
pattern Retry :: ResponseError
pattern Retry = ResponseError ( #{const RD_KAFKA_RESP_ERR__RETRY} )
pattern PurgeQueue :: ResponseError
pattern PurgeQueue = ResponseError ( #{const RD_KAFKA_RESP_ERR__PURGE_QUEUE} )
pattern PurgeInflight :: ResponseError
pattern PurgeInflight = ResponseError ( #{const RD_KAFKA_RESP_ERR__PURGE_INFLIGHT} )
pattern Fatal :: ResponseError
pattern Fatal = ResponseError ( #{const RD_KAFKA_RESP_ERR__FATAL} )
pattern Inconsistent :: ResponseError
pattern Inconsistent = ResponseError ( #{const RD_KAFKA_RESP_ERR__INCONSISTENT} )
pattern GaplessGuarantee :: ResponseError
pattern GaplessGuarantee = ResponseError ( #{const RD_KAFKA_RESP_ERR__GAPLESS_GUARANTEE} )
pattern MaxPollExceeded :: ResponseError
pattern MaxPollExceeded = ResponseError ( #{const RD_KAFKA_RESP_ERR__MAX_POLL_EXCEEDED} )
pattern UnknownBroker :: ResponseError
pattern UnknownBroker = ResponseError ( #{const RD_KAFKA_RESP_ERR__UNKNOWN_BROKER} )
pattern NotConfigured :: ResponseError
pattern NotConfigured = ResponseError ( #{const RD_KAFKA_RESP_ERR__NOT_CONFIGURED} )
pattern Fenced :: ResponseError
pattern Fenced = ResponseError ( #{const RD_KAFKA_RESP_ERR__FENCED} )
pattern Application :: ResponseError
pattern Application = ResponseError ( #{const RD_KAFKA_RESP_ERR__APPLICATION} )
pattern End :: ResponseError
pattern End = ResponseError ( #{const RD_KAFKA_RESP_ERR__END} )
pattern Unknown :: ResponseError
pattern Unknown = ResponseError ( #{const RD_KAFKA_RESP_ERR_UNKNOWN} )
pattern NoError :: ResponseError
pattern NoError = ResponseError ( #{const RD_KAFKA_RESP_ERR_NO_ERROR} )
pattern OffsetOutOfRange :: ResponseError
pattern OffsetOutOfRange = ResponseError ( #{const RD_KAFKA_RESP_ERR_OFFSET_OUT_OF_RANGE} )
pattern InvalidMsg :: ResponseError
pattern InvalidMsg = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_MSG} )
pattern UnknownTopicOrPart :: ResponseError
pattern UnknownTopicOrPart = ResponseError ( #{const RD_KAFKA_RESP_ERR_UNKNOWN_TOPIC_OR_PART} )
pattern InvalidMsgSize :: ResponseError
pattern InvalidMsgSize = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_MSG_SIZE} )
pattern LeaderNotAvailable :: ResponseError
pattern LeaderNotAvailable = ResponseError ( #{const RD_KAFKA_RESP_ERR_LEADER_NOT_AVAILABLE} )
pattern NotLeaderForPartition :: ResponseError
pattern NotLeaderForPartition = ResponseError ( #{const RD_KAFKA_RESP_ERR_NOT_LEADER_FOR_PARTITION} )
pattern RequestTimedOut :: ResponseError
pattern RequestTimedOut = ResponseError ( #{const RD_KAFKA_RESP_ERR_REQUEST_TIMED_OUT} )
pattern BrokerNotAvailable :: ResponseError
pattern BrokerNotAvailable = ResponseError ( #{const RD_KAFKA_RESP_ERR_BROKER_NOT_AVAILABLE} )
pattern ReplicaNotAvailable :: ResponseError
pattern ReplicaNotAvailable = ResponseError ( #{const RD_KAFKA_RESP_ERR_REPLICA_NOT_AVAILABLE} )
pattern MsgSizeTooLarge :: ResponseError
pattern MsgSizeTooLarge = ResponseError ( #{const RD_KAFKA_RESP_ERR_MSG_SIZE_TOO_LARGE} )
pattern StaleCtrlEpoch :: ResponseError
pattern StaleCtrlEpoch = ResponseError ( #{const RD_KAFKA_RESP_ERR_STALE_CTRL_EPOCH} )
pattern OffsetMetadataTooLarge :: ResponseError
pattern OffsetMetadataTooLarge = ResponseError ( #{const RD_KAFKA_RESP_ERR_OFFSET_METADATA_TOO_LARGE} )
pattern NetworkException :: ResponseError
pattern NetworkException = ResponseError ( #{const RD_KAFKA_RESP_ERR_NETWORK_EXCEPTION} )
pattern CoordinatorLoadInProgress :: ResponseError
pattern CoordinatorLoadInProgress = ResponseError ( #{const RD_KAFKA_RESP_ERR_COORDINATOR_LOAD_IN_PROGRESS} )
pattern CoordinatorNotAvailable :: ResponseError
pattern CoordinatorNotAvailable = ResponseError ( #{const RD_KAFKA_RESP_ERR_COORDINATOR_NOT_AVAILABLE} )
pattern NotCoordinator :: ResponseError
pattern NotCoordinator = ResponseError ( #{const RD_KAFKA_RESP_ERR_NOT_COORDINATOR} )
pattern TopicException :: ResponseError
pattern TopicException = ResponseError ( #{const RD_KAFKA_RESP_ERR_TOPIC_EXCEPTION} )
pattern RecordListTooLarge :: ResponseError
pattern RecordListTooLarge = ResponseError ( #{const RD_KAFKA_RESP_ERR_RECORD_LIST_TOO_LARGE} )
pattern NotEnoughReplicas :: ResponseError
pattern NotEnoughReplicas = ResponseError ( #{const RD_KAFKA_RESP_ERR_NOT_ENOUGH_REPLICAS} )
pattern NotEnoughReplicasAfterAppend :: ResponseError
pattern NotEnoughReplicasAfterAppend = ResponseError ( #{const RD_KAFKA_RESP_ERR_NOT_ENOUGH_REPLICAS_AFTER_APPEND} )
pattern InvalidRequiredAcks :: ResponseError
pattern InvalidRequiredAcks = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_REQUIRED_ACKS} )
pattern IllegalGeneration :: ResponseError
pattern IllegalGeneration = ResponseError ( #{const RD_KAFKA_RESP_ERR_ILLEGAL_GENERATION} )
pattern InconsistentGroupProtocol :: ResponseError
pattern InconsistentGroupProtocol = ResponseError ( #{const RD_KAFKA_RESP_ERR_INCONSISTENT_GROUP_PROTOCOL} )
pattern InvalidGroupId :: ResponseError
pattern InvalidGroupId = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_GROUP_ID} )
pattern UnknownMemberId :: ResponseError
pattern UnknownMemberId = ResponseError ( #{const RD_KAFKA_RESP_ERR_UNKNOWN_MEMBER_ID} )
pattern InvalidSessionTimeout :: ResponseError
pattern InvalidSessionTimeout = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_SESSION_TIMEOUT} )
pattern RebalanceInProgress :: ResponseError
pattern RebalanceInProgress = ResponseError ( #{const RD_KAFKA_RESP_ERR_REBALANCE_IN_PROGRESS} )
pattern InvalidCommitOffsetSize :: ResponseError
pattern InvalidCommitOffsetSize = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_COMMIT_OFFSET_SIZE} )
pattern TopicAuthorizationFailed :: ResponseError
pattern TopicAuthorizationFailed = ResponseError ( #{const RD_KAFKA_RESP_ERR_TOPIC_AUTHORIZATION_FAILED} )
pattern GroupAuthorizationFailed :: ResponseError
pattern GroupAuthorizationFailed = ResponseError ( #{const RD_KAFKA_RESP_ERR_GROUP_AUTHORIZATION_FAILED} )
pattern ClusterAuthorizationFailed :: ResponseError
pattern ClusterAuthorizationFailed = ResponseError ( #{const RD_KAFKA_RESP_ERR_CLUSTER_AUTHORIZATION_FAILED} )
pattern InvalidTimestamp :: ResponseError
pattern InvalidTimestamp = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_TIMESTAMP} )
pattern UnsupportedSaslMechanism :: ResponseError
pattern UnsupportedSaslMechanism = ResponseError ( #{const RD_KAFKA_RESP_ERR_UNSUPPORTED_SASL_MECHANISM} )
pattern IllegalSaslState :: ResponseError
pattern IllegalSaslState = ResponseError ( #{const RD_KAFKA_RESP_ERR_ILLEGAL_SASL_STATE} )
pattern UnsupportedVersion :: ResponseError
pattern UnsupportedVersion = ResponseError ( #{const RD_KAFKA_RESP_ERR_UNSUPPORTED_VERSION} )
pattern TopicAlreadyExists :: ResponseError
pattern TopicAlreadyExists = ResponseError ( #{const RD_KAFKA_RESP_ERR_TOPIC_ALREADY_EXISTS} )
pattern InvalidPartitions :: ResponseError
pattern InvalidPartitions = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_PARTITIONS} )
pattern InvalidReplicationFactor :: ResponseError
pattern InvalidReplicationFactor = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_REPLICATION_FACTOR} )
pattern InvalidReplicaAssignment :: ResponseError
pattern InvalidReplicaAssignment = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_REPLICA_ASSIGNMENT} )
pattern InvalidConfig :: ResponseError
pattern InvalidConfig = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_CONFIG} )
pattern NotController :: ResponseError
pattern NotController = ResponseError ( #{const RD_KAFKA_RESP_ERR_NOT_CONTROLLER} )
pattern InvalidRequest :: ResponseError
pattern InvalidRequest = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_REQUEST} )
pattern UnsupportedForMessageFormat :: ResponseError
pattern UnsupportedForMessageFormat = ResponseError ( #{const RD_KAFKA_RESP_ERR_UNSUPPORTED_FOR_MESSAGE_FORMAT} )
pattern PolicyViolation :: ResponseError
pattern PolicyViolation = ResponseError ( #{const RD_KAFKA_RESP_ERR_POLICY_VIOLATION} )
pattern OutOfOrderSequenceNumber :: ResponseError
pattern OutOfOrderSequenceNumber = ResponseError ( #{const RD_KAFKA_RESP_ERR_OUT_OF_ORDER_SEQUENCE_NUMBER} )
pattern DuplicateSequenceNumber :: ResponseError
pattern DuplicateSequenceNumber = ResponseError ( #{const RD_KAFKA_RESP_ERR_DUPLICATE_SEQUENCE_NUMBER} )
pattern InvalidProducerEpoch :: ResponseError
pattern InvalidProducerEpoch = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_PRODUCER_EPOCH} )
pattern InvalidTxnState :: ResponseError
pattern InvalidTxnState = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_TXN_STATE} )
pattern InvalidProducerIdMapping :: ResponseError
pattern InvalidProducerIdMapping = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_PRODUCER_ID_MAPPING} )
pattern InvalidTransactionTimeout :: ResponseError
pattern InvalidTransactionTimeout = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_TRANSACTION_TIMEOUT} )
pattern ConcurrentTransactions :: ResponseError
pattern ConcurrentTransactions = ResponseError ( #{const RD_KAFKA_RESP_ERR_CONCURRENT_TRANSACTIONS} )
pattern TransactionCoordinatorFenced :: ResponseError
pattern TransactionCoordinatorFenced = ResponseError ( #{const RD_KAFKA_RESP_ERR_TRANSACTION_COORDINATOR_FENCED} )
pattern TransactionalIdAuthorizationFailed :: ResponseError
pattern TransactionalIdAuthorizationFailed = ResponseError ( #{const RD_KAFKA_RESP_ERR_TRANSACTIONAL_ID_AUTHORIZATION_FAILED} )
pattern SecurityDisabled :: ResponseError
pattern SecurityDisabled = ResponseError ( #{const RD_KAFKA_RESP_ERR_SECURITY_DISABLED} )
pattern OperationNotAttempted :: ResponseError
pattern OperationNotAttempted = ResponseError ( #{const RD_KAFKA_RESP_ERR_OPERATION_NOT_ATTEMPTED} )
pattern KafkaStorageError :: ResponseError
pattern KafkaStorageError = ResponseError ( #{const RD_KAFKA_RESP_ERR_KAFKA_STORAGE_ERROR} )
pattern LogDirNotFound :: ResponseError
pattern LogDirNotFound = ResponseError ( #{const RD_KAFKA_RESP_ERR_LOG_DIR_NOT_FOUND} )
pattern SaslAuthenticationFailed :: ResponseError
pattern SaslAuthenticationFailed = ResponseError ( #{const RD_KAFKA_RESP_ERR_SASL_AUTHENTICATION_FAILED} )
pattern UnknownProducerId :: ResponseError
pattern UnknownProducerId = ResponseError ( #{const RD_KAFKA_RESP_ERR_UNKNOWN_PRODUCER_ID} )
pattern ReassignmentInProgress :: ResponseError
pattern ReassignmentInProgress = ResponseError ( #{const RD_KAFKA_RESP_ERR_REASSIGNMENT_IN_PROGRESS} )
pattern DelegationTokenAuthDisabled :: ResponseError
pattern DelegationTokenAuthDisabled = ResponseError ( #{const RD_KAFKA_RESP_ERR_DELEGATION_TOKEN_AUTH_DISABLED} )
pattern DelegationTokenNotFound :: ResponseError
pattern DelegationTokenNotFound = ResponseError ( #{const RD_KAFKA_RESP_ERR_DELEGATION_TOKEN_NOT_FOUND} )
pattern DelegationTokenOwnerMismatch :: ResponseError
pattern DelegationTokenOwnerMismatch = ResponseError ( #{const RD_KAFKA_RESP_ERR_DELEGATION_TOKEN_OWNER_MISMATCH} )
pattern DelegationTokenRequestNotAllowed :: ResponseError
pattern DelegationTokenRequestNotAllowed = ResponseError ( #{const RD_KAFKA_RESP_ERR_DELEGATION_TOKEN_REQUEST_NOT_ALLOWED} )
pattern DelegationTokenAuthorizationFailed :: ResponseError
pattern DelegationTokenAuthorizationFailed = ResponseError ( #{const RD_KAFKA_RESP_ERR_DELEGATION_TOKEN_AUTHORIZATION_FAILED} )
pattern DelegationTokenExpired :: ResponseError
pattern DelegationTokenExpired = ResponseError ( #{const RD_KAFKA_RESP_ERR_DELEGATION_TOKEN_EXPIRED} )
pattern InvalidPrincipalType :: ResponseError
pattern InvalidPrincipalType = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_PRINCIPAL_TYPE} )
pattern NonEmptyGroup :: ResponseError
pattern NonEmptyGroup = ResponseError ( #{const RD_KAFKA_RESP_ERR_NON_EMPTY_GROUP} )
pattern GroupIdNotFound :: ResponseError
pattern GroupIdNotFound = ResponseError ( #{const RD_KAFKA_RESP_ERR_GROUP_ID_NOT_FOUND} )
pattern FetchSessionIdNotFound :: ResponseError
pattern FetchSessionIdNotFound = ResponseError ( #{const RD_KAFKA_RESP_ERR_FETCH_SESSION_ID_NOT_FOUND} )
pattern InvalidFetchSessionEpoch :: ResponseError
pattern InvalidFetchSessionEpoch = ResponseError ( #{const RD_KAFKA_RESP_ERR_INVALID_FETCH_SESSION_EPOCH} )
pattern ListenerNotFound :: ResponseError
pattern ListenerNotFound = ResponseError ( #{const RD_KAFKA_RESP_ERR_LISTENER_NOT_FOUND} )
pattern TopicDeletionDisabled :: ResponseError
pattern TopicDeletionDisabled = ResponseError ( #{const RD_KAFKA_RESP_ERR_TOPIC_DELETION_DISABLED} )
pattern FencedLeaderEpoch :: ResponseError
pattern FencedLeaderEpoch = ResponseError ( #{const RD_KAFKA_RESP_ERR_FENCED_LEADER_EPOCH} )
pattern UnknownLeaderEpoch :: ResponseError
pattern UnknownLeaderEpoch = ResponseError ( #{const RD_KAFKA_RESP_ERR_UNKNOWN_LEADER_EPOCH} )
pattern UnsupportedCompressionType :: ResponseError
pattern UnsupportedCompressionType = ResponseError ( #{const RD_KAFKA_RESP_ERR_UNSUPPORTED_COMPRESSION_TYPE} )
pattern StaleBrokerEpoch :: ResponseError
pattern StaleBrokerEpoch = ResponseError ( #{const RD_KAFKA_RESP_ERR_STALE_BROKER_EPOCH} )
pattern OffsetNotAvailable :: ResponseError
pattern OffsetNotAvailable = ResponseError ( #{const RD_KAFKA_RESP_ERR_OFFSET_NOT_AVAILABLE} )
pattern MemberIdRequired :: ResponseError
pattern MemberIdRequired = ResponseError ( #{const RD_KAFKA_RESP_ERR_MEMBER_ID_REQUIRED} )
pattern PreferredLeaderNotAvailable :: ResponseError
pattern PreferredLeaderNotAvailable = ResponseError ( #{const RD_KAFKA_RESP_ERR_PREFERRED_LEADER_NOT_AVAILABLE} )
pattern GroupMaxSizeReached :: ResponseError
pattern GroupMaxSizeReached = ResponseError ( #{const RD_KAFKA_RESP_ERR_GROUP_MAX_SIZE_REACHED} )
pattern FencedInstanceId :: ResponseError
pattern FencedInstanceId = ResponseError ( #{const RD_KAFKA_RESP_ERR_FENCED_INSTANCE_ID} )
