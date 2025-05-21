--!strict

export type DialogueOption = {
	text: string,
	next: number,
	callback: (() -> ())?,
	displayText: string?,
	autoAdvance: boolean?,
	shouldEndDialogue: boolean?,
	condition: (() -> boolean)?,
	failCallback: (() -> ())?,
}

export type DialogueNode = {
	text: string,
	options: { DialogueOption },
	dialogueTree: DialogueTree?,
	onEnter: (() -> ())?,
	onExit: (() -> ())?,
	condition: (() -> boolean)?,
	failCallback: (() -> ())?,
}

export type DialogueTree = { DialogueNode }

export type DialogueConfig = {
	textSpeed: number?,
	autoAdvance: boolean?,
	autoAdvanceDelay: number?,
	proximityDistance: number?,
	offsetDistance: number?,
	playerTextDisplayDuration: number?,
	playerTextOffset: Vector3?,
	useScreenGui: boolean?,
}

export type PromptConfig = {
	actionText: string?,
	objectText: string?,
}

export type NPCConfig = {
	objectText: string?,
	actionText: string?,
	holdDuration: number?,
	requiresLineOfSight: boolean?,
	maxActivationDistance: number?,
	enabled: boolean?,
}

export type UIColors = {
	text: Color3,
	button: Color3,
	buttonHover: Color3,
	background: Color3,
}

export type UIConfig = {
	template: Frame?,
	optionsFrame: Frame?,
}

export type NPC = {
	model: Model,
	Prompt: ProximityPrompt?,
	dialogueTree: DialogueTree?,
	onInteract: (() -> ())?,
	FloatingText: { frame: Frame, textLabel: TextLabel }?,
	_connections: { updateConnection: RBXScriptConnection? },
}

export type DialogueSystem = {
	config: DialogueConfig,
	npc: NPC?,
	player: Player,
	character: Model?,
	rootPart: BasePart?,
	camera: Camera?,
	currentNPC: NPC?,
	options: { any },
	frame: Frame?,
	floatingPart: Part?,
	screenGui: ScreenGui?,
	currentNode: DialogueNode?,
	currentNodeIndex: number?,
	isDialogueActive: boolean,
	onOptionSelectedCallback: ((option: DialogueOption) -> ())?,
	onDialogueEndCallback: (() -> ())?,
	playerFloatingText: { frame: Frame?, textLabel: TextLabel? }?,
	_playerUpdateConnection: RBXScriptConnection?,
	_distanceCheckConnection: RBXScriptConnection?,
	_screenGuiUpdateConnection: RBXScriptConnection?,
	isNPCTyping: boolean?,

	Initialize: (self: DialogueSystem) -> (),
	SetupUI: (self: DialogueSystem) -> (),
	StartUpdateLoops: (self: DialogueSystem) -> (),
	UpdateFloatingDisplayPosition: (self: DialogueSystem) -> (),
	UpdateScreenGuiPosition: (self: DialogueSystem) -> (),
	UpdateFloatingDisplaySize: (self: DialogueSystem) -> (),
	ClearOptions: (self: DialogueSystem) -> (),
	CreateNPC: (self: DialogueSystem, npcModel: Model) -> NPC,
	StartDialogue: (self: DialogueSystem, npc: NPC, dialogueTree: DialogueTree) -> (),
	DisplayNode: (self: DialogueSystem, node: DialogueNode | number) -> (),
	ShowPlayerText: (self: DialogueSystem, text: string) -> (),
	ShowNPCText: (self: DialogueSystem, text: string, callback: (() -> ())?) -> (),
	SetConfiguration: (self: DialogueSystem, config: DialogueConfig) -> (),
	SetDialogueTree: (self: DialogueSystem, dialogueTree: DialogueTree) -> (),
	SetOnInteract: (self: DialogueSystem, callback: () -> ()) -> (),
	SetOnOptionSelected: (self: DialogueSystem, callback: (option: DialogueOption) -> ()) -> (),
	SetOnDialogueEnd: (self: DialogueSystem, callback: () -> ()) -> (),
	EndDialogue: (self: DialogueSystem) -> (),
	Destroy: (self: DialogueSystem) -> (),
}

return nil
