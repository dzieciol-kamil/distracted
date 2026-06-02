class_name Notification
extends Resource

enum InteractionType { GLANCE, ACTION, TRAP }
enum DismissAction { TAP_X, SWIPE_LEFT, ANSWER_BUTTON, READ_REPLY }

@export var content_id: String = ""
@export var sender: String = ""
@export var text: String = ""
@export var interaction: InteractionType = InteractionType.GLANCE
@export var dismiss_action: DismissAction = DismissAction.TAP_X
