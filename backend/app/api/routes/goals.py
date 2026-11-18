import uuid
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Query, Response, status

from app.api.deps import CurrentUser, GoalServiceDep
from app.schemas.goal import GoalCreate, GoalLogOut, GoalOut, GoalUpdate
from app.schemas.projection import ProjectionOut

router = APIRouter(prefix="/goals", tags=["goals"])

_NOT_FOUND = {404: {"description": "Goal not found, deleted, or owned by another user."}}


@router.get("", response_model=list[GoalOut])
def list_goals(user: CurrentUser, goals: GoalServiceDep):
    return [GoalOut.from_model(g) for g in goals.list(user)]


@router.post("", status_code=status.HTTP_201_CREATED, response_model=GoalOut)
def create_goal(data: GoalCreate, user: CurrentUser, goals: GoalServiceDep):
    return GoalOut.from_model(goals.create(user, data))


@router.get("/{goal_id}", response_model=GoalOut, responses=_NOT_FOUND)
def get_goal(goal_id: uuid.UUID, user: CurrentUser, goals: GoalServiceDep):
    return GoalOut.from_model(goals.get(user, goal_id))


@router.patch("/{goal_id}", response_model=GoalOut, responses=_NOT_FOUND)
def update_goal(goal_id: uuid.UUID, data: GoalUpdate, user: CurrentUser, goals: GoalServiceDep):
    return GoalOut.from_model(goals.update(user, goal_id, data))


@router.delete("/{goal_id}", status_code=status.HTTP_204_NO_CONTENT, responses=_NOT_FOUND)
def delete_goal(goal_id: uuid.UUID, user: CurrentUser, goals: GoalServiceDep):
    goals.delete(user, goal_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{goal_id}/history", response_model=list[GoalLogOut], responses=_NOT_FOUND)
def goal_history(goal_id: uuid.UUID, user: CurrentUser, goals: GoalServiceDep):
    entries = goals.history(user, goal_id)
    return [GoalLogOut.model_validate(e, from_attributes=True) for e in entries]


@router.get(
    "/{goal_id}/projection",
    response_model=ProjectionOut,
    responses=_NOT_FOUND,
    summary="Required monthly SIP and year-by-year corpus",
)
def goal_projection(
    goal_id: uuid.UUID,
    user: CurrentUser,
    goals: GoalServiceDep,
    as_of: Annotated[
        date | None, Query(description="Calculate as of this date. Defaults to today.")
    ] = None,
):
    """Level SIP and step-up SIP plans, the target in today's money, and a yearly table.

    Returns are illustrative assumptions, not guarantees.
    """
    goal, projection = goals.projection(user, goal_id, as_of)
    return ProjectionOut.build(goal, projection)
