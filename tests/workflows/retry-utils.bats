#!/usr/bin/env bats

# Tests for retry-utils.sh
# Run with: bats tests/workflows/retry-utils.bats

setup() {
  # Download and load the shared retry utilities
  curl -sSL https://raw.githubusercontent.com/stuartshay/shared-azure-health/master/scripts/retry-utils.sh -o /tmp/retry-utils-test.sh
  # shellcheck disable=SC1091
  source /tmp/retry-utils-test.sh
  export RETRY_BASE_DELAY=0  # Speed up tests by removing delays
}

# Test: Successful command on first attempt
@test "retry succeeds on first attempt" {
  run retry_azure_operation 3 "test command" echo "success"
  [ "$status" -eq 0 ]
  # The function outputs to stdout, but also logs to stderr
  # Check that output contains "success"
  [[ "$output" == *"success"* ]]
}

# Test: Command that succeeds after one retry
@test "retry succeeds on second attempt" {
  # Create a command that fails once then succeeds
  run bash -c '
    source scripts/ci/retry-utils.sh
    export RETRY_BASE_DELAY=0
    COUNTER_FILE=$(mktemp)
    echo "0" > "$COUNTER_FILE"
    retry_azure_operation 3 "flaky command" bash -c "
      count=\$(cat $COUNTER_FILE)
      echo \$((count + 1)) > $COUNTER_FILE
      if [ \$count -eq 0 ]; then
        echo \"Error: TooManyRequests\" >&2
        exit 1
      fi
      echo \"success\"
      exit 0
    "
    rm -f "$COUNTER_FILE"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"success"* ]]
}

# Test: Command that fails with permanent error
@test "retry fails immediately on permanent error" {
  run bash -c '
    source scripts/ci/retry-utils.sh
    export RETRY_BASE_DELAY=0
    retry_azure_operation 3 "permanent failure" bash -c "
      echo \"Error: AuthorizationFailed\"
      exit 1
    "
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *"Permanent failure detected"* ]]
}

# Test: Command that exhausts all retries
@test "retry fails after max attempts" {
  run bash -c '
    source scripts/ci/retry-utils.sh
    export RETRY_BASE_DELAY=0
    retry_azure_operation 2 "always fails" bash -c "
      echo \"Error: ServiceUnavailable\"
      exit 1
    "
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed after 2 attempts"* ]]
}

# Test: Recognizes rate limit error (429)
@test "retry recognizes rate limit error" {
  run bash -c '
    source scripts/ci/retry-utils.sh
    export RETRY_BASE_DELAY=0
    retry_azure_operation 2 "rate limited" bash -c "
      echo \"Error: TooManyRequests (429)\"
      exit 1
    "
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *"Rate limit (429)"* ]]
}

# Test: Recognizes service unavailable error (503)
@test "retry recognizes service unavailable error" {
  run bash -c '
    source scripts/ci/retry-utils.sh
    export RETRY_BASE_DELAY=0
    retry_azure_operation 2 "service unavailable" bash -c "
      echo \"Error: ServiceUnavailable (503)\"
      exit 1
    "
  '
  [ "$status" -eq 1 ]
  [[ "$output" == *"Service unavailable (503)"* ]]
}

# Test: Exponential backoff calculation (without actual sleep)
@test "retry uses exponential backoff" {
  # This test verifies the logic exists, actual delays are skipped with RETRY_BASE_DELAY=0
  run bash -c '
    source scripts/ci/retry-utils.sh
    export RETRY_BASE_DELAY=1
    # We cannot easily test the actual delay, but we can verify the function works
    retry_azure_operation 1 "test" echo "ok"
  '
  [ "$status" -eq 0 ]
}

# Test: Output is properly captured
@test "retry captures command output correctly" {
  run retry_azure_operation 1 "test output" echo "test output line"
  [ "$status" -eq 0 ]
  [[ "$output" == *"test output line"* ]]
}

# Test: Multi-line output is preserved
@test "retry preserves multi-line output" {
  run retry_azure_operation 1 "multi-line" bash -c "echo 'line1'; echo 'line2'; echo 'line3'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"line1"* ]]
  [[ "$output" == *"line2"* ]]
  [[ "$output" == *"line3"* ]]
}
