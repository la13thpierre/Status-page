variable "alert_email" {
  description = "Email address that receives up/down alerts"
  type        = string
}

resource "aws_sns_topic" "alerts" {
  name = "status-page-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

data "aws_iam_policy_document" "checker_sns" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
  }
}

resource "aws_iam_role_policy" "checker_sns" {
  name   = "checker-sns"
  role   = aws_iam_role.checker.id
  policy = data.aws_iam_policy_document.checker_sns.json
}